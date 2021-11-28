#!/usr/local/bin/python3
# - *- coding: utf- 8 - *-

# /usr/syno/synoman/webman/3rdparty/synOCR/includes/parse_date.py


from dateutil.parser import parse
from dateutil.tz import tzlocal
from datetime import date as d
import re
import sys

lst = [
    ["January",
     "Januar",
     "Januarie",
     "януари",
     "一月",
     "siječanj",
     "leden",
     "januar",
     "januari",
     "January",
     "tammikuu",
     "janvier",
     "Januar",
     "Ιανουάριος",
     "január",
     "gennaio",
     "1月",
     "1월",
     "januar",
     "styczeń",
     "janeiro",
     "ianuarie",
     "январь",
     "januari",
     "január",
     "januar",
     "enero",
     "Ocak",
     "січень",
     "tháng một", ],
    ["February",
     "Februar",
     "Februarie",
     "февруари",
     "二月",
     "veljača",
     "únor",
     "februar",
     "februari",
     "February",
     "helmikuu",
     "février",
     "Februar",
     "Φεβρουάριος",
     "február",
     "febbraio",
     "2月",
     "2월",
     "februar",
     "luty",
     "fevereiro",
     "februarie",
     "февраль",
     "februari",
     "február",
     "februar",
     "febrero",
     "Şubat",
     "лютий",
     "Tháng Hai", ],
    ["March",
     "März",
     "Maart",
     "март",
     "三月",
     "ožujak",
     "březen",
     "marts",
     "maart",
     "March",
     "maaliskuu",
     "mars",
     "März",
     "Μάρτιος",
     "március",
     "marzo",
     "3月",
     "3월",
     "mars",
     "marzec",
     "março",
     "martie",
     "март",
     "mars",
     "marec",
     "marec",
     "marzo",
     "Mart",
     "Березень",
     "diễu hành", ],
    ["April",
     "April",
     "April",
     "април",
     "四月",
     "travanj",
     "duben",
     "april",
     "april",
     "April",
     "huhtikuu",
     "avril",
     "April",
     "Απρίλιος",
     "április",
     "aprile",
     "4月",
     "4월",
     "april",
     "kwiecień",
     "abril",
     "aprilie",
     "апрель",
     "april",
     "apríl",
     "april",
     "abril",
     "Nisan",
     "Квітень",
     "Tháng Tư", ],
    ["May",
     "Mai",
     "Mei",
     "май",
     "五月",
     "svibanj",
     "květen",
     "maj",
     "mei",
     "May",
     "saattaa",
     "mai",
     "Mai",
     "Μάιος",
     "május",
     "maggio",
     "5月",
     "5월",
     "mai",
     "maj",
     "maio",
     "mai",
     "май",
     "maj",
     "máj",
     "maj",
     "mayo",
     "Mayıs",
     "травень",
     "có thể", ],
    ["June",
     "Juni",
     "Junie",
     "юни",
     "六月",
     "lipanj",
     "červen",
     "juni",
     "juni",
     "June",
     "kesäkuu",
     "juin",
     "Juni",
     "Ιούνιος",
     "június",
     "giugno",
     "6月",
     "6월",
     "juni",
     "czerwiec",
     "junho",
     "iunie",
     "июнь",
     "juni",
     "jún",
     "junij",
     "junio",
     "Haziran",
     "Червень",
     "Tháng Sáu", ],
    ["July",
     "Juli",
     "Julie",
     "юли",
     "七月",
     "srpanj",
     "červenec",
     "juli",
     "juli",
     "July",
     "heinäkuu",
     "juillet",
     "Juli",
     "Ιούλιος",
     "július",
     "luglio",
     "7月",
     "7월",
     "juli",
     "lipiec",
     "julho",
     "iulie",
     "июль",
     "juli",
     "júl",
     "julij",
     "julio",
     "Temmuz",
     "Липень",
     "Tháng Bảy", ],
    ["August",
     "August",
     "Augustus",
     "август",
     "八月",
     "kolovoz",
     "srpen",
     "august",
     "augustus",
     "August",
     "elokuu",
     "août",
     "August",
     "Αύγουστος",
     "augusztus",
     "agosto",
     "8月",
     "8월",
     "august",
     "sierpień",
     "agosto",
     "august",
     "август",
     "augusti",
     "august",
     "avgust",
     "agosto",
     "Ağustos",
     "Серпень",
     "uy nghi", ],
    ["September",
     "September",
     "September",
     "септември",
     "九月",
     "rujan",
     "září",
     "september",
     "september",
     "September",
     "syyskuu",
     "septembre",
     "September",
     "Σεπτέμβριος",
     "szeptember",
     "settembre",
     "9月",
     "9월",
     "september",
     "wrzesień",
     "setembro",
     "septembrie",
     "сентябрь",
     "september",
     "septembra",
     "september",
     "septiembre",
     "Eylül",
     "вересень",
     "Tháng Chín", ],
    ["October",
     "Oktober",
     "Oktober",
     "октомври",
     "十月",
     "listopad",
     "říjen",
     "oktober",
     "oktober",
     "October",
     "lokakuu",
     "octobre",
     "Oktober",
     "Οκτώβριος",
     "október",
     "ottobre",
     "10月",
     "10월",
     "oktober",
     "październik",
     "outubro",
     "octombrie",
     "октябрь",
     "oktober",
     "október",
     "oktober",
     "octubre",
     "Ekim",
     "Жовтень",
     "Tháng Mười", ],
    ["November",
     "November",
     "November",
     "ноември",
     "十一月",
     "studeni",
     "listopad",
     "november",
     "november",
     "November",
     "marraskuu",
     "novembre",
     "November",
     "Νοέμβριος",
     "november",
     "novembre",
     "11月",
     "11월",
     "november",
     "listopad",
     "novembro",
     "noiembrie",
     "ноябрь",
     "november",
     "november",
     "november",
     "noviembre",
     "Kasım",
     "Листопад",
     "Tháng Mười Một", ],
    ["December",
     "Dezember",
     "Desember",
     "декември",
     "十二月",
     "prosinac",
     "prosinec",
     "december",
     "december",
     "December",
     "joulukuu",
     "décembre",
     "Dezember",
     "Δεκέμβριος",
     "december",
     "dicembre",
     "12月",
     "12월",
     "desember",
     "grudzień",
     "dezembro",
     "decembrie",
     "декабрь",
     "december",
     "december",
     "december",
     "diciembre",
     "Aralık",
     "грудень",
     "Tháng mười hai", ]
]


month_name_map = {}


#def prepare(line: str) -> str:
def prepare(line):
    global month_name_map

    # first : int[int]....int[int]..intintintint
    # second: int[int]<len(whitspace) > 0><non whitespace...><len(whitspace) > 0>intintintint
    regex = [
        r"([\d]{1,2}).+([\d]{1,2}).+([\d]{4})",
        r"([\d]{1,2})[.\s]+([\S]+)[\s]+([\d]{4})",
    ]
    for r in regex:
        match = re.search(r, line)
        if match:
            # these are strings
            day = match.group(1)
            month = match.group(2)
            year = match.group(3)
            try:
                date = d(year=int(year), month=int(month), day=int(day))
                return date.isoformat()
            except:
                try:
                    month = month_name_map[month]  # January -> 1
                    date = d(year=int(year), month=int(month), day=int(day))
                    return date.isoformat()
                except:
                    continue

    # no match, return input string
    return line


def init_months_names_map():
    global month_name_map

    # initialize dictionary with every possible capitalization
    for idx, month_names in enumerate(lst):
        for month in month_names:
            
            number = idx + 1
            month_name_map[month] = number
            month_name_map[month.lower()] = number
            month_name_map[month.upper()] = number
            month_name_map[month.capitalize()] = number
            month_name_map[month.casefold()] = number

            # every possible abbreviation beginning with the first 3 characters
            for i in range(3, len(month)):
                short_name = month[:i] + "."  # Mär. Okt. etc.(len = 3), Okto. Oktob, Oktobe.(len [4, 5, 6, ...])
                month_name_map[short_name] = number
                month_name_map[short_name.lower()] = number
                month_name_map[short_name.upper()] = number
                month_name_map[short_name.capitalize()] = number
                month_name_map[short_name.casefold()] = number


if __name__ == "__main__":
    init_months_names_map()
    timzone = tzlocal()

    # retrieve command line arguments
    content_path = sys.argv[1]
    content = open(content_path,'r')

    for txt in content:
        try:
            dt = parse(prepare(txt), fuzzy=True, tzinfos=[timzone])
            
        except ValueError:
            #print("\t\t\tERROR, unkonw format")
            print("\t\t\tERROR, unknown format:", txt)
        else:
            print(dt.date())


exit(0)

