// =============================================================================
// RodONService.exe — привілейована частина RodON для Windows (без Qt)
//
// Режими запуску:
//   RodONService.exe --install      реєструє і запускає службу "RodONService"
//                                   (викликає інсталятор, потрібні права адміна)
//   RodONService.exe --uninstall    зупиняє тунель, видаляє обидві служби
//   RodONService.exe --stop         зупиняє службу і тунель (перед оновленням)
//   RodONService.exe /service <f>   процес служби тунелю — запускає SCM,
//                                   всередині працює tunnel.dll (WireGuardNT)
//   (без аргументів)                менеджер-служба, запускає SCM
//
// Менеджер слухає \\.\pipe\RodONService. Протокол (UTF-8, запит закінчується
// порожнім рядком, відповідь — один рядок):
//   CONNECT\nprivate_key=..\naddress=..\ndns=..\npublic_key=..\nendpoint=..\n\n
//       -> OK | ERR <текст>
//   DISCONNECT\n\n          -> OK | ERR <текст>
//   STATUS\n\n              -> STATUS <disconnected|connecting|connected|
//                                      disconnecting|error> <rx> <tx> <code>
// =============================================================================
#include <winsock2.h>
#include <windows.h>
#include <sddl.h>
#include <cctype>
#include <cstdio>
#include <cstdarg>
#include <cstring>
#include <cwchar>
#include <map>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "wireguard.h"   // з wireguard-nt: include/wireguard.h

namespace {

const wchar_t kManagerName[]    = L"RodONService";
const wchar_t kManagerDisplay[] = L"RodON VPN Service";
const wchar_t kTunnelName[]     = L"RodON";                  // ім'я адаптера і .conf
const wchar_t kTunnelService[]  = L"WireGuardTunnel$RodON";  // вимога tunnel.dll
const wchar_t kPipeName[]       = L"\\\\.\\pipe\\RodONService";

// Тека з конфігом: лише SYSTEM і адміністратори (у конфігу приватний ключ)
const wchar_t kDirSddl[]  = L"D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)";
const wchar_t kFileSddl[] = L"D:P(A;;FA;;;SY)(A;;FA;;;BA)";
// Pipe: SYSTEM, адміни, інтерактивні користувачі (звичайний RodON.exe)
const wchar_t kPipeSddl[] = L"D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;IU)";

const ULONGLONG kHandshakeStale = 180ULL * 10000000ULL; // 180 c у 100-нс одиницях

std::mutex g_opMutex;   // CONNECT/DISCONNECT/STATUS виконуються по черзі
std::mutex g_logMutex;
HANDLE g_stopEvent = nullptr;
SERVICE_STATUS_HANDLE g_statusHandle = nullptr;
SERVICE_STATUS g_status{};

// ---------------------------------------------------------------- утиліти
std::wstring exePath()
{
    wchar_t buf[MAX_PATH * 2];
    DWORD n = GetModuleFileNameW(nullptr, buf, ARRAYSIZE(buf));
    return std::wstring(buf, n);
}

std::wstring exeDir()
{
    std::wstring p = exePath();
    return p.substr(0, p.find_last_of(L"\\/"));
}

std::wstring dataDir()
{
    wchar_t buf[MAX_PATH];
    ExpandEnvironmentStringsW(L"%ProgramData%\\RodON", buf, ARRAYSIZE(buf));
    return buf;
}

std::wstring confPath() { return dataDir() + L"\\" + kTunnelName + L".conf"; }

void logLine(const char* fmt, ...)
{
    std::lock_guard<std::mutex> lk(g_logMutex);
    FILE* f = _wfopen((dataDir() + L"\\service.log").c_str(), L"a");
    if (!f) return;
    SYSTEMTIME t; GetLocalTime(&t);
    fprintf(f, "%04d-%02d-%02d %02d:%02d:%02d ", t.wYear, t.wMonth, t.wDay,
            t.wHour, t.wMinute, t.wSecond);
    va_list ap; va_start(ap, fmt); vfprintf(f, fmt, ap); va_end(ap);
    fputc('\n', f);
    fclose(f);
}

struct SecAttr {
    SECURITY_ATTRIBUTES sa{ sizeof(SECURITY_ATTRIBUTES), nullptr, FALSE };
    explicit SecAttr(const wchar_t* sddl)
    {
        ConvertStringSecurityDescriptorToSecurityDescriptorW(
            sddl, SDDL_REVISION_1, &sa.lpSecurityDescriptor, nullptr);
    }
    ~SecAttr() { if (sa.lpSecurityDescriptor) LocalFree(sa.lpSecurityDescriptor); }
    SECURITY_ATTRIBUTES* get() { return &sa; }
};

void ensureDataDir()
{
    SecAttr sa(kDirSddl);
    const std::wstring dir = dataDir();
    if (!CreateDirectoryW(dir.c_str(), sa.get()) && GetLastError() == ERROR_ALREADY_EXISTS)
        SetFileSecurityW(dir.c_str(), DACL_SECURITY_INFORMATION, sa.sa.lpSecurityDescriptor);
}

bool writeConf(const std::string& text)
{
    ensureDataDir();
    SecAttr sa(kFileSddl);
    HANDLE f = CreateFileW(confPath().c_str(), GENERIC_WRITE, 0, sa.get(),
                           CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (f == INVALID_HANDLE_VALUE) return false;
    DWORD n = 0;
    BOOL ok = WriteFile(f, text.data(), DWORD(text.size()), &n, nullptr);
    CloseHandle(f);
    return ok && n == text.size();
}

// ---------------------------------------------------------------- SCM
struct Sc {
    SC_HANDLE h = nullptr;
    Sc(SC_HANDLE x = nullptr) : h(x) {}
    ~Sc() { if (h) CloseServiceHandle(h); }
    Sc(const Sc&) = delete; Sc& operator=(const Sc&) = delete;
    operator SC_HANDLE() const { return h; }
    explicit operator bool() const { return h != nullptr; }
};

bool waitState(SC_HANDLE s, DWORD wanted, DWORD timeoutMs)
{
    SERVICE_STATUS st{};
    for (DWORD waited = 0; waited <= timeoutMs; waited += 100) {
        if (!QueryServiceStatus(s, &st)) return false;
        if (st.dwCurrentState == wanted) return true;
        Sleep(100);
    }
    return false;
}

// Зупиняє і видаляє службу; чекає, доки SCM справді її прибере
bool stopAndDelete(SC_HANDLE scm, const wchar_t* name)
{
    {
        Sc s(OpenServiceW(scm, name, SERVICE_STOP | SERVICE_QUERY_STATUS | DELETE));
        if (!s) return GetLastError() == ERROR_SERVICE_DOES_NOT_EXIST;
        SERVICE_STATUS st{};
        ControlService(s, SERVICE_CONTROL_STOP, &st);
        waitState(s, SERVICE_STOPPED, 15000);
        if (!DeleteService(s) && GetLastError() != ERROR_SERVICE_MARKED_FOR_DELETE)
            return false;
    }
    for (int i = 0; i < 100; ++i) {
        Sc t(OpenServiceW(scm, name, SERVICE_QUERY_STATUS));
        if (!t) return true;
        Sleep(100);
    }
    return false;
}

bool teardownTunnel()
{
    Sc scm(OpenSCManagerW(nullptr, nullptr, SC_MANAGER_ALL_ACCESS));
    if (!scm) return false;
    bool ok = stopAndDelete(scm, kTunnelService);
    DeleteFileW(confPath().c_str());
    logLine("teardown: %s", ok ? "ok" : "FAILED");
    return ok;
}

// ---------------------------------------------------------------- wireguard.dll
struct WgApi {
    HMODULE dll = nullptr;
    WIREGUARD_OPEN_ADAPTER_FUNC* open = nullptr;
    WIREGUARD_CLOSE_ADAPTER_FUNC* close = nullptr;
    WIREGUARD_GET_CONFIGURATION_FUNC* getConfig = nullptr;

    bool load()
    {
        if (dll) return open && close && getConfig;
        dll = LoadLibraryExW((exeDir() + L"\\wireguard.dll").c_str(), nullptr,
                             LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (!dll) return false;
        open      = (WIREGUARD_OPEN_ADAPTER_FUNC*)GetProcAddress(dll, "WireGuardOpenAdapter");
        close     = (WIREGUARD_CLOSE_ADAPTER_FUNC*)GetProcAddress(dll, "WireGuardCloseAdapter");
        getConfig = (WIREGUARD_GET_CONFIGURATION_FUNC*)GetProcAddress(dll, "WireGuardGetConfiguration");
        return open && close && getConfig;
    }
} g_wg;

// Дані першого (єдиного) піра: трафік і час останнього handshake
bool peerStats(ULONGLONG& rx, ULONGLONG& tx, ULONGLONG& lastHandshake)
{
    rx = tx = lastHandshake = 0;
    if (!g_wg.load()) return false;
    WIREGUARD_ADAPTER_HANDLE a = g_wg.open(kTunnelName);
    if (!a) return false;
    std::vector<BYTE> buf(4096);
    DWORD bytes = DWORD(buf.size());
    bool ok = false;
    for (int i = 0; i < 4; ++i) {
        if (g_wg.getConfig(a, reinterpret_cast<WIREGUARD_INTERFACE*>(buf.data()), &bytes)) { ok = true; break; }
        if (GetLastError() != ERROR_MORE_DATA) break;
        buf.resize(bytes);
    }
    g_wg.close(a);
    if (!ok) return false;
    auto* iface = reinterpret_cast<WIREGUARD_INTERFACE*>(buf.data());
    if (iface->PeersCount < 1) return false;
    auto* peer = reinterpret_cast<WIREGUARD_PEER*>(iface + 1);
    rx = peer->RxBytes;
    tx = peer->TxBytes;
    lastHandshake = peer->LastHandshake;
    return true;
}

ULONGLONG nowFiletime()
{
    FILETIME ft; GetSystemTimeAsFileTime(&ft);
    return (ULONGLONG(ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
}

// ---------------------------------------------------------------- команди
bool isKey(const std::string& s)
{
    if (s.size() != 44 || s[43] != '=') return false;
    for (size_t i = 0; i < 43; ++i) {
        unsigned char c = s[i];
        if (!isalnum(c) && c != '+' && c != '/') return false;
    }
    return true;
}

bool onlyChars(const std::string& s, const char* extra)
{
    if (s.empty() || s.size() > 200) return false;
    for (unsigned char c : s)
        if (!isalnum(c) && !strchr(extra, c)) return false;
    return true;
}

std::string cmdConnect(std::map<std::string, std::string>& kv)
{
    std::string priv = kv["private_key"], pub = kv["public_key"];
    std::string addr = kv["address"], dns = kv["dns"], endpoint = kv["endpoint"];

    if (!isKey(priv))                     return "ERR invalid private key\n";
    if (!isKey(pub))                      return "ERR invalid server public key\n";
    if (!onlyChars(addr, ".:/,"))         return "ERR invalid address\n";
    if (!onlyChars(endpoint, ".-:[]"))    return "ERR invalid endpoint\n";
    if (dns.empty()) dns = "1.1.1.1";
    if (!onlyChars(dns, ".:, "))          return "ERR invalid dns\n";
    if (addr.find('/') == std::string::npos)
        addr += (addr.find(':') == std::string::npos) ? "/32" : "/128";

    // ::/0 теж у тунель: інакше IPv6 піде повз VPN
    std::string conf =
        "[Interface]\r\n"
        "PrivateKey = " + priv + "\r\n"
        "Address = " + addr + "\r\n"
        "DNS = " + dns + "\r\n\r\n"
        "[Peer]\r\n"
        "PublicKey = " + pub + "\r\n"
        "Endpoint = " + endpoint + "\r\n"
        "AllowedIPs = 0.0.0.0/0, ::/0\r\n"
        "PersistentKeepalive = 25\r\n";

    if (!teardownTunnel())  return "ERR could not stop previous tunnel\n";
    if (!writeConf(conf))   return "ERR could not write config\n";

    Sc scm(OpenSCManagerW(nullptr, nullptr, SC_MANAGER_ALL_ACCESS));
    if (!scm) return "ERR OpenSCManager failed\n";

    const std::wstring cmd = L"\"" + exePath() + L"\" /service \"" + confPath() + L"\"";
    Sc s(CreateServiceW(scm, kTunnelService, L"RodON Tunnel", SERVICE_ALL_ACCESS,
                        SERVICE_WIN32_OWN_PROCESS, SERVICE_DEMAND_START, SERVICE_ERROR_NORMAL,
                        cmd.c_str(), nullptr, nullptr, L"Nsi\0TcpIp\0", nullptr, nullptr));
    if (!s) {
        logLine("CreateService(tunnel) failed: %lu", GetLastError());
        return "ERR could not create tunnel service\n";
    }
    SERVICE_SID_INFO sid{ SERVICE_SID_TYPE_UNRESTRICTED };   // обов'язково для tunnel.dll
    ChangeServiceConfig2W(s, SERVICE_CONFIG_SERVICE_SID_INFO, &sid);

    if (!StartServiceW(s, 0, nullptr)) {
        DWORD e = GetLastError();
        logLine("StartService(tunnel) failed: %lu", e);
        DeleteService(s);
        return "ERR could not start tunnel (" + std::to_string(e) + ")\n";
    }
    logLine("connect: tunnel service started, endpoint %s", endpoint.c_str());
    return "OK\n";
}

std::string cmdStatus()
{
    Sc scm(OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT));
    if (!scm) return "STATUS error 0 0 1\n";
    Sc s(OpenServiceW(scm, kTunnelService, SERVICE_QUERY_STATUS));
    if (!s) return "STATUS disconnected 0 0 0\n";

    SERVICE_STATUS st{};
    if (!QueryServiceStatus(s, &st)) return "STATUS error 0 0 2\n";

    ULONGLONG rx = 0, tx = 0, hs = 0;
    std::string state;
    DWORD code = 0;
    switch (st.dwCurrentState) {
    case SERVICE_START_PENDING:
        state = "connecting"; break;
    case SERVICE_RUNNING:
        peerStats(rx, tx, hs);
        state = (hs != 0 && nowFiletime() - hs < kHandshakeStale) ? "connected" : "connecting";
        break;
    case SERVICE_STOP_PENDING:
        state = "disconnecting"; break;
    default: // STOPPED
        code = (st.dwWin32ExitCode == ERROR_SERVICE_SPECIFIC_ERROR)
                   ? st.dwServiceSpecificExitCode : st.dwWin32ExitCode;
        state = code ? "error" : "disconnected";
        break;
    }
    return "STATUS " + state + " " + std::to_string(rx) + " " + std::to_string(tx) +
           " " + std::to_string(code) + "\n";
}

// ---------------------------------------------------------------- pipe
bool pipeIo(HANDLE pipe, bool write, void* buf, DWORD len, DWORD& done)
{
    OVERLAPPED ov{};
    ov.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    done = 0;
    BOOL ok = write ? WriteFile(pipe, buf, len, &done, &ov)
                    : ReadFile(pipe, buf, len, &done, &ov);
    if (!ok && GetLastError() == ERROR_IO_PENDING) {
        if (WaitForSingleObject(ov.hEvent, 10000) != WAIT_OBJECT_0)
            CancelIoEx(pipe, &ov);
        ok = GetOverlappedResult(pipe, &ov, &done, TRUE);
    }
    CloseHandle(ov.hEvent);
    return ok && done > 0;
}

void handleClient(HANDLE pipe)
{
    std::string req;
    char buf[1024];
    DWORD n = 0;
    while (req.size() < 16384 && pipeIo(pipe, false, buf, sizeof(buf), n)) {
        for (DWORD i = 0; i < n; ++i) if (buf[i] != '\r') req += buf[i];
        if (req.find("\n\n") != std::string::npos) break;
    }

    std::string cmd, resp;
    std::map<std::string, std::string> kv;
    size_t pos = 0;
    for (bool first = true; pos < req.size(); first = false) {
        size_t end = req.find('\n', pos);
        if (end == std::string::npos) end = req.size();
        std::string line = req.substr(pos, end - pos);
        pos = end + 1;
        if (line.empty()) break;
        if (first) { cmd = line; continue; }
        size_t eq = line.find('=');
        if (eq != std::string::npos) kv[line.substr(0, eq)] = line.substr(eq + 1);
    }

    {
        std::lock_guard<std::mutex> lk(g_opMutex);
        if (cmd == "CONNECT")         resp = cmdConnect(kv);
        else if (cmd == "DISCONNECT") resp = teardownTunnel() ? "OK\n" : "ERR could not stop tunnel\n";
        else if (cmd == "STATUS")     resp = cmdStatus();
        else                          resp = "ERR unknown command\n";
    }
    if (!req.empty()) SecureZeroMemory(&req[0], req.size());   // приватний ключ не лишаємо в пам'яті
    for (auto& p : kv) if (!p.second.empty()) SecureZeroMemory(&p.second[0], p.second.size());

    pipeIo(pipe, true, resp.data(), DWORD(resp.size()), n);
    FlushFileBuffers(pipe);
    DisconnectNamedPipe(pipe);
    CloseHandle(pipe);
}

DWORD WINAPI pipeServer(LPVOID)
{
    SecAttr sa(kPipeSddl);
    for (;;) {
        HANDLE pipe = CreateNamedPipeW(
            kPipeName, PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED,
            PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS,
            PIPE_UNLIMITED_INSTANCES, 4096, 4096, 0, sa.get());
        if (pipe == INVALID_HANDLE_VALUE) {
            logLine("CreateNamedPipe failed: %lu", GetLastError());
            if (WaitForSingleObject(g_stopEvent, 1000) == WAIT_OBJECT_0) return 0;
            continue;
        }
        OVERLAPPED ov{};
        ov.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
        bool connected = ConnectNamedPipe(pipe, &ov) != FALSE;
        if (!connected) {
            DWORD e = GetLastError();
            if (e == ERROR_PIPE_CONNECTED) connected = true;
            else if (e == ERROR_IO_PENDING) {
                HANDLE hs[2] = { ov.hEvent, g_stopEvent };
                if (WaitForMultipleObjects(2, hs, FALSE, INFINITE) == WAIT_OBJECT_0) {
                    DWORD dummy;
                    connected = GetOverlappedResult(pipe, &ov, &dummy, FALSE) != FALSE;
                } else {
                    CancelIoEx(pipe, &ov);
                    CloseHandle(ov.hEvent);
                    CloseHandle(pipe);
                    return 0;   // служба зупиняється
                }
            }
        }
        CloseHandle(ov.hEvent);
        if (connected) std::thread(handleClient, pipe).detach();
        else CloseHandle(pipe);
    }
}

// ---------------------------------------------------------------- менеджер-служба
void setStatus(DWORD state)
{
    g_status.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
    g_status.dwCurrentState = state;
    g_status.dwControlsAccepted = (state == SERVICE_RUNNING)
        ? SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN : 0;
    g_status.dwWaitHint = 20000;
    SetServiceStatus(g_statusHandle, &g_status);
}

void WINAPI ctrlHandler(DWORD ctrl)
{
    if (ctrl == SERVICE_CONTROL_STOP || ctrl == SERVICE_CONTROL_SHUTDOWN) {
        setStatus(SERVICE_STOP_PENDING);
        SetEvent(g_stopEvent);
    }
}

void WINAPI managerMain(DWORD, LPWSTR*)
{
    g_statusHandle = RegisterServiceCtrlHandlerW(kManagerName, ctrlHandler);
    if (!g_statusHandle) return;
    setStatus(SERVICE_START_PENDING);

    g_stopEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    ensureDataDir();
    logLine("manager: starting");
    {   // тунель, що лишився з минулого запуску/перезавантаження
        std::lock_guard<std::mutex> lk(g_opMutex);
        teardownTunnel();
    }
    HANDLE th = CreateThread(nullptr, 0, pipeServer, nullptr, 0, nullptr);
    setStatus(SERVICE_RUNNING);

    WaitForSingleObject(g_stopEvent, INFINITE);
    WaitForSingleObject(th, 5000);
    {
        std::lock_guard<std::mutex> lk(g_opMutex);
        teardownTunnel();
    }
    logLine("manager: stopped");
    setStatus(SERVICE_STOPPED);
}

// ---------------------------------------------------------------- install/uninstall
int install()
{
    Sc scm(OpenSCManagerW(nullptr, nullptr, SC_MANAGER_ALL_ACCESS));
    if (!scm) { fwprintf(stderr, L"OpenSCManager failed: %lu (run as admin)\n", GetLastError()); return 1; }

    const std::wstring cmd = L"\"" + exePath() + L"\"";
    Sc s(OpenServiceW(scm, kManagerName, SERVICE_ALL_ACCESS));
    if (s) {
        SERVICE_STATUS st{};
        ControlService(s, SERVICE_CONTROL_STOP, &st);
        waitState(s, SERVICE_STOPPED, 20000);
        ChangeServiceConfigW(s, SERVICE_WIN32_OWN_PROCESS, SERVICE_AUTO_START, SERVICE_ERROR_NORMAL,
                             cmd.c_str(), nullptr, nullptr, L"Nsi\0TcpIp\0", nullptr, nullptr,
                             kManagerDisplay);
    } else {
        s.h = CreateServiceW(scm, kManagerName, kManagerDisplay, SERVICE_ALL_ACCESS,
                             SERVICE_WIN32_OWN_PROCESS, SERVICE_AUTO_START, SERVICE_ERROR_NORMAL,
                             cmd.c_str(), nullptr, nullptr, L"Nsi\0TcpIp\0", nullptr, nullptr);
        if (!s) { fwprintf(stderr, L"CreateService failed: %lu\n", GetLastError()); return 1; }
    }

    wchar_t descr[] = L"Manages RodON VPN connections";
    SERVICE_DESCRIPTIONW d{ descr };
    ChangeServiceConfig2W(s, SERVICE_CONFIG_DESCRIPTION, &d);

    SC_ACTION actions[3] = { { SC_ACTION_RESTART, 5000 }, { SC_ACTION_RESTART, 5000 }, { SC_ACTION_RESTART, 30000 } };
    SERVICE_FAILURE_ACTIONSW fa{ 86400, nullptr, nullptr, 3, actions };
    ChangeServiceConfig2W(s, SERVICE_CONFIG_FAILURE_ACTIONS, &fa);

    if (!StartServiceW(s, 0, nullptr) && GetLastError() != ERROR_SERVICE_ALREADY_RUNNING) {
        fwprintf(stderr, L"StartService failed: %lu\n", GetLastError());
        return 1;
    }
    waitState(s, SERVICE_RUNNING, 20000);
    wprintf(L"RodONService installed and running\n");
    return 0;
}

int stopAll(bool remove)
{
    Sc scm(OpenSCManagerW(nullptr, nullptr, SC_MANAGER_ALL_ACCESS));
    if (!scm) { fwprintf(stderr, L"OpenSCManager failed: %lu (run as admin)\n", GetLastError()); return 1; }

    if (remove) {
        stopAndDelete(scm, kManagerName);
    } else {
        Sc s(OpenServiceW(scm, kManagerName, SERVICE_STOP | SERVICE_QUERY_STATUS));
        if (s) {
            SERVICE_STATUS st{};
            ControlService(s, SERVICE_CONTROL_STOP, &st);
            waitState(s, SERVICE_STOPPED, 20000);
        }
    }
    stopAndDelete(scm, kTunnelService);   // на випадок, якщо менеджер не встиг
    DeleteFileW(confPath().c_str());
    if (remove) {
        const std::wstring dir = dataDir();
        for (const wchar_t* f : { L"\\service.log", L"\\log.bin" })
            DeleteFileW((dir + f).c_str());
        RemoveDirectoryW(dir.c_str());
    }
    return 0;
}

// ---------------------------------------------------------------- процес тунелю
int runTunnelService(const wchar_t* conf)
{
    HMODULE dll = LoadLibraryExW((exeDir() + L"\\tunnel.dll").c_str(), nullptr,
                                 LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!dll) return 2;
    using Fn = bool (*)(const wchar_t*);
    auto fn = reinterpret_cast<Fn>(GetProcAddress(dll, "WireGuardTunnelService"));
    if (!fn) return 3;
    return fn(conf) ? 0 : 1;   // всередині tunnel.dll сама викликає StartServiceCtrlDispatcher
}

} // namespace

int wmain(int argc, wchar_t** argv)
{
    if (argc == 3 && _wcsicmp(argv[1], L"/service") == 0) return runTunnelService(argv[2]);
    if (argc == 2 && _wcsicmp(argv[1], L"--install") == 0)   return install();
    if (argc == 2 && _wcsicmp(argv[1], L"--uninstall") == 0) return stopAll(true);
    if (argc == 2 && _wcsicmp(argv[1], L"--stop") == 0)      return stopAll(false);

    SERVICE_TABLE_ENTRYW table[] = { { const_cast<LPWSTR>(kManagerName), managerMain }, { nullptr, nullptr } };
    if (!StartServiceCtrlDispatcherW(table)) {
        if (GetLastError() == ERROR_FAILED_SERVICE_CONTROLLER_CONNECT)
            fwprintf(stderr, L"Usage: RodONService.exe --install | --uninstall | --stop\n");
        return 1;
    }
    return 0;
}
