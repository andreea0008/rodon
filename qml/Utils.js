.pragma library


function pngIcon(name) {
    return qsTr("qrc:/qt/qml/SVPN/icons/%1.png").arg(name)
}

var flagMap = ({
    "ad": "andorra", "ae": "united arab emirates", "af": "afghanistan",
    "ag": "antigua and barbuda", "ai": "anguilla", "al": "albania",
    "am": "armenia", "ao": "angola", "aq": "antarctica", "ar": "argentina",
    "as": "american samoa", "at": "austria", "au": "australia", "aw": "aruba",
    "az": "azerbaijan", "ba": "bosnia and herzegovina", "bb": "barbados",
    "bd": "bangladesh", "be": "belgium", "bf": "burkina faso", "bg": "bulgaria",
    "bh": "bahrain", "bi": "burundi", "bj": "benin", "bm": "bermuda",
    "bn": "brunei", "bo": "bolivia", "bq": "bonaire", "br": "brazil",
    "bs": "bahamas", "bt": "bhutan", "bw": "botswana", "by": "belarus",
    "bz": "belize", "ca": "canada", "cd": "democratic republic of congo",
    "cf": "central african republic", "cg": "republic of the congo",
    "ch": "switzerland", "ci": "ivory coast", "ck": "cook islands",
    "cl": "chile", "cm": "cameroon", "cn": "china", "co": "colombia",
    "cr": "costa rica", "cu": "cuba", "cv": "cape verde", "cw": "curacao",
    "cy": "cyprus", "cz": "czech republic", "de": "germany", "dj": "djibouti",
    "dk": "denmark", "dm": "dominica", "do": "dominican republic",
    "dz": "Algeria", "ec": "ecuador", "ee": "estonia", "eg": "egypt",
    "eh": "sahrawi arab democratic republic", "er": "eritrea", "es": "spain",
    "et": "ethiopia", "eu": "european union", "fi": "finland", "fj": "fiji",
    "fk": "falkland islands", "fm": "micronesia", "fo": "faroe islands",
    "fr": "france", "ga": "gabon", "gb": "united kingdom", "gd": "grenada",
    "ge": "georgia", "gg": "guernsey", "gh": "ghana", "gi": "gibraltar",
    "gl": "greenland", "gm": "gambia", "gn": "guinea", "gq": "equatorial guinea",
    "gr": "greece", "gt": "guatemala", "gu": "guam", "gw": "guinea bissau",
    "gy": "guyana", "hk": "hong kong", "hn": "honduras", "hr": "croatia",
    "ht": "haiti", "hu": "hungary", "id": "indonesia", "ie": "ireland",
    "il": "israel", "im": "isle of man", "in": "india",
    "io": "british indian ocean territory", "iq": "iraq", "ir": "iran",
    "is": "iceland", "it": "italy", "je": "jersey", "jm": "jamaica",
    "jo": "jordan", "jp": "japan", "ke": "kenya", "kg": "kyrgyzstan",
    "kh": "cambodia", "ki": "kiribati", "km": "comoros",
    "kn": "st barts", "kp": "north korea", "kr": "south korea",
    "kw": "kuwait", "ky": "cayman islands", "kz": "kazakhstan", "la": "laos",
    "lb": "lebanon", "lc": "st lucia", "li": "liechtenstein", "lk": "sri lanka",
    "lr": "liberia", "ls": "lesotho", "lt": "lithuania", "lu": "luxembourg",
    "lv": "latvia", "ly": "libya", "ma": "morocco", "mc": "monaco",
    "md": "moldova", "me": "montenegro", "mf": "sint maarten", "mg": "madagascar",
    "mh": "marshall island", "mk": "republic of macedonia", "ml": "mali",
    "mm": "myanmar", "mn": "mongolia", "mo": "macao",
    "mp": "northern marianas islands", "mq": "martinique", "mr": "mauritania",
    "ms": "montserrat", "mt": "malta", "mu": "mauritius", "mv": "maldives",
    "mw": "malawi", "mx": "mexico", "my": "malaysia", "mz": "mozambique",
    "na": "namibia", "ne": "niger", "nf": "norfolk island", "ng": "nigeria",
    "ni": "nicaragua", "nl": "netherlands", "no": "norway", "np": "nepal",
    "nr": "nauru", "nu": "niue", "nz": "new zealand", "om": "oman",
    "pa": "panama", "pe": "peru", "pf": "french polynesia",
    "pg": "papua new guinea", "ph": "philippines", "pk": "pakistan",
    "pl": "poland", "pn": "pitcairn islands", "pr": "puerto rico",
    "ps": "palestine", "pt": "portugal", "pw": "palau", "py": "paraguay",
    "qa": "qatar", "ro": "romania", "rs": "serbia", "ru": "russia",
    "rw": "rwanda", "sa": "saudi arabia", "sb": "solomon islands",
    "sc": "seychelles", "sd": "sudan", "se": "sweden", "sg": "singapore",
    "si": "slovenia", "sk": "slovakia", "sl": "sierra leone", "sm": "san marino",
    "sn": "senegal", "so": "somalia", "sr": "suriname", "ss": "south sudan",
    "st": "sao tome and prince", "sv": "el salvador", "sx": "sint maarten",
    "sy": "syria", "sz": "swaziland", "tc": "turks and caicos", "td": "chad",
    "tg": "togo", "th": "thailand", "tj": "tajikistan", "tk": "tokelau",
    "tl": "East Timor", "tm": "turkmenistan", "tn": "tunisia", "to": "tonga",
    "tr": "turkey", "tt": "trinidad and tobago", "tv": "tuvalu", "tw": "taiwan",
    "tz": "tanzania", "ua": "ukraine", "ug": "uganda", "us": "united states",
    "uy": "uruguay", "uz": "uzbekistan", "va": "vatican city",
    "vc": "st vincent and the grenadines", "ve": "venezuela",
    "vg": "british virgin islands", "vi": "virgin islands", "vn": "vietnam",
    "vu": "vanuatu", "ws": "samoa", "ye": "yemen", "za": "south africa",
    "zm": "zambia", "zw": "zimbabwe"
})

function pngFlag(country) {
    return "qrc:/qt/qml/SVPN/icons/flags/" + country + ".png"
}

function flagCountryByCode(code) {
    if (!code) return ""
    var c = code.toLowerCase()
    // legacy aliases
    if (c === "en" || c === "uk") return pngFlag(c === "en" ? "united kingdom" : "ukraine")
    var name = flagMap[c]
    return name ? pngFlag(name) : pngFlag("finland")
}
