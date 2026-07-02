#######################################################################
#  Parse Textfiles for valid dates.
#  Check if dates were not listed in a blacklist and/or were not in the future
#  Actually following date formats were supported
#  DD-/.MM-/.YYYY  / means or
#  returnvalue = founddate YYYY-MM-DD or None
#
#  Author: gthorsten
#  Version:
#
#     1.08, 02.07.2026 (by GLM 5.2)
#           International date parsing + OCR error tolerance:
#           - new CLI param -lang (Tesseract -l value, e.g. "deu+eng") as locale hint
#           - comprehensive TESS_TO_DATEPARSER mapping (Tesseract code -> dateparser language + DATE_ORDER priority)
#           - fix inconsistent locale: check_year_range/check_blacklist now use the resolved languages
#             instead of the previously hardcoded ['de'] / missing language
#           - numeric disambiguation: >12 rule + DATE_ORDER priority from -l for ambiguous numeric
#             dates like 02.07.2026
#           - widen alphanumeric regex charset to support accented month names (fr/es/it/pt/nl ...)
#           - OCR digit-confusable tolerance: new _OCR_DIGIT_CONFUSABLES map (O/o->0, l/I/|->1,
#             Z/z->2, A->4, S/s->5, b->6, T->7, B->8, g/q->9); search_all_numeric_dates matches
#             against a per-line normalised copy so misread digits (e.g. "2O26", "Ol.07.2O26") are
#             recovered (alpha month search and shell tag search untouched)
#           - OCR separator-confusable tolerance: new _OCR_SEPARATOR_CONFUSABLES map (comma -> dot,
#             en/em/minus/hyphen-variants -> hyphen) so misread separators (e.g. "1,7,2026",
#             "2026-07-15" with a unicode dash) are recovered in the numeric pass
#           - the existing positional regexes + year-range/blacklist filters keep invalid normalised
#             candidates (e.g. day 48) out automatically
#           - single-digit days (without leading zero) are now recognised in the numeric pass
#             (day slot gains a trailing |[1-9]); fixes "1.7.2026" / "2026-07-1". Also fixes a
#             latent month-slot typo in the D-M-Y (whitespace=true) pattern
#           - defensive None-guard added in check_blacklist
#     1.07, 30.09.2024
#           Fix for dateparser parsing current datetime from invalid string (thx @dklinger)
#           Bugfix for dates like 15.6.2023
#           add language = de to dateparser (thx @dklinger)
#     1.06, 26.10.2023
#           search_alpha_numeric_dates()
#           -change regex after user hint
#     1.05, 26.03.2023
#           search_alpha_numeric_dates()
#           - optimize search for short dates (jun., Apr......)
#           - bugfix regex with whitespace after Month
#           - add some logging
#     1.04, 08.03.2023
#           remove bugfix with Mai
#           add () as sourrounding for numerical dates
#           add tests
#     1.03, 16.09.2002
#           add unit test
#           bugfix numeric date search
#           bugfix blacklist dates
#
#     1.02, 12.09.2002
#           bugfix search numeric dates. Dates direct at start
#
#     1.01, 12.09.2002
#           bugfix unitest prparation
#
#     1.00, 12.09.2002
#           optimze datesearch
#           add unittest preparation
#
#     0.94, 25.08.2022
#           search_alpha_numeric_dates()
#           - Bugfix for alphanumeric dates.
#             
#
#     0.93, 11.08.2022
#           search_all_numeric_dates()
#           - split pattern for D.M.Y, D-M-Y, D/M/Y in different pattern strings.
#             using or (.|/|/) gives sometimes bad results
#
#     0.92, 10.08.2022
#           add version string for logging
#           change regexstr for search_all_numeric_dates. Whitespace at start
#
#     0.91, 21.07.2022
#           add logging for parameter search nearest
#
#     0.9, 26.06.2022
#          bugfix: minYear,maxYear could be >= or <= instead of < and >
#     0.8, 19.06.2022
#          rework numeric date search
#          supported following formats:
#           1.  DD-|.|/MM-|.|/YYYY
#           2.  DD-|.|/MM-|.|/YY
#           3.  YYYY-|.|/MM-|.|/DD
#           4.  YY-|.|/MM-|.|/DD
#
#     0.7, 08.06.2022
#          remove logging for everyline in alpha search
#          add Parameter minYear/maxYear
#              range 0, 1900-2200, 0:means unlimited
#          rework alphanumeric search and add long dates 11. April 2002 and short dates April 2022
#
#     0.6, 01.06.2022
#          BugFix search_alpha_numeric_dates
#          Regex \a-zA-Z -> a-zA-z
#
#     0.5, 30.05.2022
#          enable logging things happens during date search
#          new parameter: dbg_lvl and dbg_file
#                         dbg_lvl = 0 (off), 1=info, 2=debug
#                         dbg_file = filename with path to write logging info
#          rework alphanumeric date search.
#          - prescan every line with regex, otherwise date_search was to bad
#
#     0.4, 13.05.2022
#          add correct timezone to dateparser calls to prevent PEP Message
#          enable alphanumeric date search ( needed parts month, year)
#          actual behaviour:
#          - search all alpha-numeric date
#          - search all numeric dates and append
#          - if not search nearest first found alphanumeric date ist returned
#          - if no alpha date is found first numeric date is returned
#
#     0.3, 03.05.2022
#          splitt_dates: Bugfix for dateformar YMD
#     0.2, 01.04.2022
#          remove exit on error for call ArgumentParser(exit_on_error=False)
#     0.1, 24.03.2022
#
#
#
# search_alpha_numeric_dates
import datetime

from dateparser.search import search_dates
import dateparser.parser
import re
import os
import sys
import argparse
import logging
from pathlib import Path


# ---------------------------------------------------------------------------
# International date parsing support (v1.08)
# ---------------------------------------------------------------------------
# The Tesseract OCR language passed via OCRmyPDF "-l" (e.g. "deu+eng") is used
# as a locale hint. It is mapped to:
#   * a list of dateparser languages (so written-out month names are parsed in
#     the right language), and
#   * an ordered list of DATE_ORDER preferences ("DMY"/"MDY"/"YMD") used to
#     disambiguate purely numeric dates such as 02.07.2026.
# The mapping intentionally only references languages that dateparser actually
# ships; for Tesseract codes without a dateparser equivalent the language list
# is set to None (dateparser then falls back to auto-detection).

# Shared DATE_ORDER priority lists. The first entry is preferred, the others
# act as fallbacks for the >12 disambiguation in search_all_numeric_dates.
_ORDER_DMY = ["DMY", "YMD", "MDY"]
_ORDER_MDY = ["MDY", "DMY", "YMD"]
_ORDER_YMD = ["YMD", "DMY", "MDY"]

# Tesseract traineddata code -> (dateparser languages | None, ordered DATE_ORDER list).
TESS_TO_DATEPARSER = {
    # --- Day-Month-Year (the most common ordering worldwide) ---
    "deu": (["de"], _ORDER_DMY),
    "fra": (["fr"], _ORDER_DMY),
    "ita": (["it"], _ORDER_DMY),
    "spa": (["es"], _ORDER_DMY),
    "por": (["pt"], _ORDER_DMY),
    "nld": (["nl"], _ORDER_DMY),
    "dan": (["da"], _ORDER_DMY),
    "fin": (["fi"], _ORDER_DMY),
    "nor": (["nb"], _ORDER_DMY),
    "swe": (["sv"], _ORDER_DMY),
    "rus": (["ru"], _ORDER_DMY),
    "ukr": (["uk"], _ORDER_DMY),
    "pol": (["pl"], _ORDER_DMY),
    "ces": (["cs"], _ORDER_DMY),
    "slk": (["sk"], _ORDER_DMY),
    "ron": (["ro"], _ORDER_DMY),
    "tur": (["tr"], _ORDER_DMY),
    "ell": (["el"], _ORDER_DMY),
    "heb": (["he"], _ORDER_DMY),
    "ara": (["ar"], _ORDER_DMY),
    "bul": (["bg"], _ORDER_DMY),
    "hrv": (["hr"], _ORDER_DMY),
    "srp": (["sr"], _ORDER_DMY),
    "slv": (["sl"], _ORDER_DMY),
    "lav": (["lv"], _ORDER_DMY),
    "lit": (["lt"], _ORDER_DMY),
    "est": (["et"], _ORDER_DMY),
    "isl": (["is"], _ORDER_DMY),
    "afr": (["af"], _ORDER_DMY),
    "sqi": (["sq"], _ORDER_DMY),
    "mkd": (["mk"], _ORDER_DMY),
    "bel": (["be"], _ORDER_DMY),
    "kaz": (["kk"], _ORDER_DMY),
    "uzb": (["uz"], _ORDER_DMY),
    "hye": (["hy"], _ORDER_DMY),
    "kat": (["ka"], _ORDER_DMY),
    "guj": (["gu"], _ORDER_DMY),
    "pan": (["pa"], _ORDER_DMY),
    "ori": (["or"], _ORDER_DMY),
    "sin": (["si"], _ORDER_DMY),
    "san": (["sa"], _ORDER_DMY),
    "amh": (["am"], _ORDER_DMY),
    "swa": (["sw"], _ORDER_DMY),
    "cym": (["cy"], _ORDER_DMY),
    "gle": (["ga"], _ORDER_DMY),
    "glg": (["gl"], _ORDER_DMY),
    "eus": (["eu"], _ORDER_DMY),
    "cat": (["ca"], _ORDER_DMY),
    "mlt": (["mt"], _ORDER_DMY),
    "snd": (["sd"], _ORDER_DMY),
    "pus": (["ps"], _ORDER_DMY),
    "mya": (["my"], _ORDER_DMY),
    "khm": (["km"], _ORDER_DMY),
    "lao": (["lo"], _ORDER_DMY),
    "div": (["dv"], _ORDER_DMY),
    "bod": (["bo"], _ORDER_DMY),
    "dzo": (["dz"], _ORDER_DMY),
    "vie": (["vi"], _ORDER_DMY),
    "tha": (["th"], _ORDER_DMY),
    "ind": (["id"], _ORDER_DMY),
    "msa": (["ms"], _ORDER_DMY),
    "jav": (["jv"], _ORDER_DMY),
    "ben": (["bn"], _ORDER_DMY),
    "tam": (["ta"], _ORDER_DMY),
    "tel": (["te"], _ORDER_DMY),
    "urd": (["ur"], _ORDER_DMY),
    "nep": (["ne"], _ORDER_DMY),
    "hin": (["hi"], _ORDER_DMY),
    "mar": (["mr"], _ORDER_DMY),
    "asm": (["as"], _ORDER_DMY),
    "tgl": (["fil"], _ORDER_DMY),
    "fil": (["fil"], _ORDER_DMY),
    "hat": (["ht"], _ORDER_DMY),
    "ltz": (["lb"], _ORDER_DMY),
    "hbs": (["hr", "sr", "bs"], _ORDER_DMY),
    # --- Year-Month-Day ---
    "chi_sim": (["zh"], _ORDER_YMD),
    "chi_tra": (["zh"], _ORDER_YMD),
    "jpn": (["ja"], _ORDER_YMD),
    "kor": (["ko"], _ORDER_YMD),
    "hun": (["hu"], _ORDER_YMD),
    "mon": (["mn"], _ORDER_YMD),
    "fas": (["fa"], _ORDER_YMD),
    "per": (["fa"], _ORDER_YMD),
    # --- Month-Day-Year (US English; DMY kept as fallback via the >12 rule) ---
    "eng": (["en"], _ORDER_MDY),
    # --- Orientation/script only, or no dateparser equivalent: neutral fallback ---
    # osd only detects script/orientation and carries no language information.
    # Historical/script codes (enm, lat, grc, frk, frm, ita_old, spa_old, chr,
    # cos, ton, iku, yid, kur, syr, tat, uig, tgk, yor ...) are intentionally
    # not mapped: their dateparser language support is missing or uncertain, so
    # they fall through to the neutral default below (auto-detect + DMY first).
    "osd": (None, _ORDER_DMY),
}

# Letters allowed inside (possibly accented) month names. Widened from the
# previous German-only "a-zA-Z\u00e4\u00c4" so that international month names
# such as French "fevrier"/"octobre", Spanish "marzo"/"mayo", Italian "giugno",
# Portuguese "maio" or Dutch "maart" are matched. The alpha search runs with
# re.IGNORECASE, so the lowercase accented letters below also cover uppercase.
_MONTH_LETTERS = "a-zA-Z\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5\u00e6\u00e7\u00e8\u00e9\u00ea\u00eb\u00ec\u00ed\u00ee\u00ef\u00f0\u00f1\u00f2\u00f3\u00f4\u00f5\u00f6\u00f8\u00f9\u00fa\u00fb\u00fc\u00fd\u00fe\u00ff"

# OCR digit confusables (v1.09). Tesseract sometimes misreads digits as letters.
# To recover such numeric dates, search_all_numeric_dates matches against a
# per-line copy translated with this map (see search_all_numeric_dates). The map
# is intentionally case-sensitive (e.g. "B"->8 but "b"->6) and kept to the
# realistic, lower-risk confusions; risky/common letters (D, Q, E, i, h, G, t,
# lowercase "a") are deliberately excluded to limit false positives in prose.
# Invalid normalised values (e.g. day "48") are rejected automatically by the
# existing positional regexes plus the year-range/blacklist filters.
_OCR_DIGIT_CONFUSABLES = str.maketrans({
    "O": "0", "o": "0",
    "l": "1", "I": "1", "|": "1",
    "Z": "2", "z": "2",
    "A": "4",
    "S": "5", "s": "5",
    "b": "6",
    "T": "7",
    "B": "8",
    "g": "9", "q": "9",
})

# OCR separator confusables (v1.09). Tesseract sometimes misreads the date
# separators: a dot becomes a comma ("1,7,2026") or a hyphen becomes an en/em
# dash or a minus sign ("2026\u201307\u201315"). The numeric pass normalises
# these to the canonical separators expected by the existing regexes (dot and
# ASCII hyphen). Like the digit map above this is applied to the numeric pass
# only and is 1:1, so positions/lengths are preserved. Comma->dot is safe
# because the positional regexes (day/month width, 2/4-digit year) reject
# number-group artefacts such as "1.000.000"; dash variants are safe because a
# dash between words cannot form the required digit/separator/digit structure.
_OCR_SEPARATOR_CONFUSABLES = str.maketrans({
    ",": ".",
    "\u2010": "-",   # hyphen
    "\u2011": "-",   # non-breaking hyphen
    "\u2012": "-",   # figure dash
    "\u2013": "-",   # en dash
    "\u2014": "-",   # em dash
    "\u2212": "-",   # minus sign
})


def resolve_lang_hint(ocr_lang_raw):
    """Resolve a Tesseract -l value (e.g. "deu+eng") into a
    (dateparser_languages | None, ordered DATE_ORDER list) tuple.

    Script variants such as "deu_frak" or "jpn_vert" are reduced to their base
    code before lookup. Unknown or empty input falls back to the neutral
    default (no language, DMY first), which matches the previous behaviour.
    """
    default_orders = ["DMY", "YMD", "MDY"]
    if not ocr_lang_raw:
        return None, default_orders
    langs, orders, seen = [], [], set()
    for raw in ocr_lang_raw.split("+"):
        code = raw.strip().lower()
        info = TESS_TO_DATEPARSER.get(code)
        if info is None and "_" in code:
            # Not all underscored codes are script variants: "chi_sim"/"chi_tra"
            # are real Tesseract language codes and are mapped directly above.
            # Only when the full code is unknown do we try stripping a script
            # suffix, e.g. "deu_frak" -> "deu" or "jpn_vert" -> "jpn".
            info = TESS_TO_DATEPARSER.get(code.rsplit("_", 1)[0])
        if not info:
            continue
        dp_langs, dp_orders = info
        if dp_langs:
            for lang in dp_langs:
                if lang not in seen:
                    seen.add(lang)
                    langs.append(lang)
        for order in dp_orders:
            if order not in orders:
                orders.append(order)
    return (langs or None), (orders or default_orders)


class FindDates:

    def __init__(self):
        self.fileWithTextFindings = None
        self.dateBlackList_YMD = []
        self.dateBlackList_DMY = []
        self.searchtextstr = None
        self.founddatelist = []
        self.searchnearest = False
        self.dbg_lvl = 0
        self.dbg_file = None
        self.numeric_dates_cnt = 0
        self.alphanumeric_dates_cnt = 0
        self.version = '1.08'
        self.found_date_cnt = 0
                       

        now = datetime.datetime.now()
        self.year_now = now.year
        self.minYear = 0
        self.maxYear = 0
        # Locale hint derived from the Tesseract -l value (see resolve_lang_hint).
        # self.langs defaults to ['de'] so that profiles without a -l hint keep the
        # previous German-centric behaviour. self.date_orders drives the priority
        # used to disambiguate purely numeric dates in search_all_numeric_dates.
        self.langs = ['de']
        self.date_orders = ["DMY", "YMD", "MDY"]

    def setfindmode(self, searchnearest):
        if searchnearest.casefold() == "on":
            self.searchnearest = True

    def add_file_with_text_findings(self, filewithtextfindings):

        try:
            with open(filewithtextfindings, 'r', encoding='UTF-8') as f:
                self.searchtextstr = " ".join([line.rstrip() for line in f])
                self.fileWithTextFindings = filewithtextfindings
        except FileNotFoundError:
            print(f"ERROR: File {filewithtextfindings} not accesible")
            print("File is not accessible", file=sys.stderr)
        finally:
            f.close()

    def split_dates(self, date_string):
        """
        search in date_string for numerical date-values used as blacklist dates
        :param date_string:
        :return: founddatelist contains a list of datetime objects
        """
        founddatelist = []
        # The blacklist (ignoredDate) is stored and compared as YYYY-MM-DD by the
        # shell side (see synOCR.sh), so only the YMD pattern is needed here.
        # This intentionally stays locale-independent regardless of the -l hint.
        regexlist = [
            #r"(0[1-9]|[12][0-9]|3[01]|[1-9])(-|\.)(0[1-9]|1[0-2])(-|\.)\d{4}",  # DDMMYYY
            r"\d{4}(-|\.)(0[1-9]|1[0-2])(-|\.)(0[1-9]|[12][0-9]|3[01])"  # YYYYMMDD
        ]

        logging.info('start split_dates')
        for singleregex in regexlist:
            startpos = 0
            while startpos < len(date_string):
                result = re.search(singleregex, date_string[startpos:])
                if result:  # , settings={'DATE_ORDER': 'DMY'}
                    #parseresult = dateparser.parse(result.group(0), settings={'DATE_ORDER': 'DMY', 'TIMEZONE': 'CEST'})
                    #if not parseresult:
                    parseresult = dateparser.parse(result.group(0),
                                                       settings={'DATE_ORDER': 'YMD', 'TIMEZONE': 'CEST'})

                    if parseresult:
                        # founddatelist.append(f"{parseresult.day:02d}.{parseresult.month:02d}.{parseresult.year:4d}")
                        founddatelist.append(parseresult)
                    startpos += result.end()
                else:
                    break
        logging.info('end split_dates')
        return founddatelist

    def add_black_list(self, dateblacklist):
        """
        splitt string dateblacklist in datetime objects
        :param dateblacklist:
        :return:
        """
        logging.info('start checking blacklist')
        blackListDates = self.split_dates(dateblacklist)
        if blackListDates:
            for blackListDate in blackListDates:
                founddate = f"{blackListDate.year:04d}.{blackListDate.month:02d}.{blackListDate.day:02d}"
                logging.debug(f'Blacklistdate {founddate}')
                # print(founddate)
                self.dateBlackList_YMD.append(founddate)
                founddate = f"{blackListDate.day:02d}.{blackListDate.month:02d}.{blackListDate.year:04d}"
                self.dateBlackList_DMY.append(founddate)

        logging.info('end checking blacklist')

    def check_year_range(self, regex_result, settings_str):
        # def check_year_range(self, date_str, settings_str):
        # Locale (dateparser languages) now comes from the -l hint via
        # self.langs instead of the previously hardcoded ['de']. check_blacklist
        # below uses the same languages so both methods stay consistent.
        date_obj = dateparser.parse(regex_result.group(0), settings=settings_str, languages=self.langs)
        now = datetime.datetime.now()
        if not date_obj or abs((now - date_obj).total_seconds()) < 5:
            date_obj = None

        if date_obj:
            act_value = f"{date_obj.day:02d}.{date_obj.month:02d}.{date_obj.year:04d}"
            logging.debug(f'Found date {act_value}')
            if date_obj:
                if (self.minYear == 0 or date_obj.year >= self.minYear) \
                        and (self.maxYear == 0 or date_obj.year <= self.maxYear):
                    logging.debug(f'{date_obj} is valid with minYear{self.minYear} and maxYear={self.maxYear}')
                    return True
                else:
                    logging.debug(f'{date_obj} is out of range minYear{self.minYear} and maxYear={self.maxYear}')

        return False

    def check_blacklist(self, regex_result, settings_str):
        # Use the same self.langs as check_year_range so a date that passed the
        # year-range check is parsed identically here (previously this call used
        # dateparser auto-detection, which could diverge from check_year_range).
        date_obj = dateparser.parse(regex_result.group(0), settings=settings_str, languages=self.langs)
        # dateparser may return None for invalid/unparseable strings. With the
        # v1.09 OCR-confusable normalisation producing extra numeric candidates,
        # guard explicitly before touching date_obj fields (check_year_range
        # already rejects most of these, but stay safe against AttributeError).
        if date_obj is None:
            logging.debug('check_blacklist: dateparser returned None, skipping candidate')
            return
        act_value = f"{date_obj.day:02d}.{date_obj.month:02d}.{date_obj.year:04d}"
                                                        
        if date_obj:
            if date_obj not in self.founddatelist:
                if len(self.dateBlackList_DMY):
                    if act_value not in self.dateBlackList_DMY:
                        self.founddatelist.append(date_obj)
                        logging.debug(f'add {date_obj} because not in blacklist')
                        self.found_date_cnt += 1
                else:
                    self.founddatelist.append(date_obj)
                    logging.debug(f'add anyway {date_obj}. no blacklist present')
                    self.found_date_cnt += 1
            else:
                logging.debug(f'do not add {date_obj} because it is already there')

    def _effective_date_order(self, pattern_order, matched_text):
        """Return the DATE_ORDER to feed dateparser for a numeric match.

        YMD matches are unambiguous (the 4-digit year comes first). For DMY and
        MDY matches the first two components may both be <= 12, which is
        ambiguous: 02.07.2026 could be 2 July (DMY) or 7 February (MDY). In that
        case self.date_orders (derived from the Tesseract -l hint) decides.

        If one of the first two components is > 12 it is unambiguously the day
        and therefore fixes the order directly (first component > 12 -> DMY,
        second component > 12 -> MDY). Because the DMY/MDY regexes constrain
        their month slot to <= 12, only the day slot can ever exceed 12.

        Both the DMY and the MDY pattern of an ambiguous date yield the same
        effective order here, so check_blacklist de-duplicates them to a single
        date object.
        """
        if pattern_order == "YMD":
            return "YMD"
        numbers = re.findall(r"\d+", matched_text)
        if len(numbers) < 3:
            # Unexpected match shape - fall back to the regex's nominal order.
            return pattern_order
        a, b = int(numbers[0]), int(numbers[1])
        if a > 12 and b <= 12:
            return "DMY"
        if b > 12 and a <= 12:
            return "MDY"
        # Both <= 12 (ambiguous) -> use the locale's preferred DMY/MDY order.
        for order in self.date_orders:
            if order in ("DMY", "MDY"):
                return order
        return "DMY"

    def search_all_numeric_dates(self, act_line):
        """
        Search for numeric dates in self.searchtextstr
        return value is always an list. empty if no date found, otherwise contains a list of datetime objects
        """
        founddate = None
        # reg für zahlendatums
        # 12.12.2022
        # 12.12.20     (DD.MM.YY)
        # (0[1-9]|[12][0-9]|3[01]|[1-9])(-|\.)(0[1-9]|1[0-2])(-|\.)\d{4}(\s|\.|\,)
        # DD-|.|/MM-|.|/YYYY
        # DD-|.|/MM-|.|/YY
        #
        # !!!!! \s?(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(-|\.|\/)(\s?)(0[1-9]|1[0-2])(\s?)(-|\.|\/)(\s?)(\d{4}|\d{2})(\s|\.|\,)
        # /(0[1-9]|[12][0-9]|3[01]|[1-9])(-|\.|\/)(0[1-9]|1[0-2])(-|\.|\/)\d{4}/gm
        # YYYY-|.|/MM-|.|/DD
        # YY-|.|/MM-|.|/DD
        #
        # !!!!! \s?(((\d{4})(\s?)(-|\.|\/)(\s?))|((\d{2})(\s?)(-|\.|\/)(\s?)))(0[1-9]|1[0-2])(\s?)(-|\.|\/)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])(\.|\,|\s)

        #max_len = len(self.searchtextstr)

        regexlist = [
            # v1.09: day slots accept a single-digit day too (trailing |[1-9], tried
            # last so 2-digit forms keep priority), so dates like "1.7.2026" or
            # "2026-07-1" are recognised. Month slots already allowed 1-digit months
            # (DMY/MDY); YMD month stays 2-digit (ISO convention). The blacklist
            # parser (split_dates) intentionally keeps 2-digit-only day slots.
            # Y-M-D
            (r"((\s)|(\())(((\d{4})(\s?)(-)(\s?)))(0[1-9]|1[0-2])(\s?)(-)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])((\.|\,|\s|\))|\s*$)", "YMD", True),
            # Y.M.D
            (r"((\s)|(\())(((\d{4})(\s?)(\.)(\s?)))(0[1-9]|1[0-2])(\s?)(\.)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])((\.|\,|\s|\))|\s*$)", "YMD", True),
            # Y/M/D
            (r"((\s)|(\())(((\d{4})(\s?)(\/)(\s?)))(0[1-9]|1[0-2])(\s?)(\/)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])((\.|\,|\s|\))|\s*$)", "YMD", True),
            # D-M-Y
            (r"((\s)|(\())(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(-)(\s?)(0[1-9]|[1-9]|1[0-2])(\s?)(-)(\s?)(\d{2}|\d{4})((\.|\,|\s|\))|\s*$)", "DMY", True),
            # D.M.Y
            (r"((\s)|(\())(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(\.)(\s?)(0[1-9]|[1-9]|1[0-2])(\s?)(\.)(\s?)(\d{2}|\d{4})((\.|\,|\s|\))|\s*$)", "DMY", True),
            # D/M/Y
            (r"((\s)|(\())(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(\/)(\s?)(0[1-9]|[1-9]|1[0-2])(\s?)(\/)(\s?)(\d{2}|\d{4})((\.|\,|\s|\))|\s*$)", "DMY", True),
            # whitespace = false
            # Y-M-D
            (r"((\s*)|(\())(((\d{4})(\s?)(-)(\s?)))(0[1-9]|1[0-2])(\s?)(-)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])((\.|\,|\s|\))|\s*$)", "YMD", False),
            # Y.M.D
            (r"((\s*)|(\())(((\d{4})(\s?)(\.)(\s?)))(0[1-9]|1[0-2])(\s?)(\.)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])((\.|\,|\s|\))|\s*$)","YMD", False),
            # Y/M/D
            (r"((\s*)|(\())(((\d{4})(\s?)(\/)(\s?)))(0[1-9]|1[0-2])(\s?)(\/)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])((\.|\,|\s|\))|\s*$)","YMD", False),

            # D-M-Y
            (r"((\s*)|(\())(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(-)(\s?)(0[1-9]|[1-9]|1[0-2])(\s?)(-)(\s?)(\d{2}|\d{4})((\.|\,|\s|\))|\s*$)", "DMY", False),
            # D.M.Y
            (r"((\s*)|(\())(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(\.)(\s?)(0[1-9]|[1-9]|1[0-2])(\s?)(\.)(\s?)(\d{2}|\d{4})((\.|\,|\s|\))|\s*$)", "DMY", False),
            # D/M/Y
            (r"((\s*)|(\())(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(\/)(\s?)(0[1-9]|1[0-2])(\s?)(\/)(\s?)(\d{2}|\d{4})((\.|\,|\s|\))|\s*$)", "DMY", False),
            # --- M-D-Y / M.D.Y / M/D/Y (needed so day>12 in the second position,
            # e.g. "07/13/2026", is recognised at all). Ambiguous cases
            # (both components <= 12) are resolved in _effective_date_order. ---
            # M-D-Y (whitespace = true)
            (r"((\s)|(\())(0[1-9]|1[0-2]|[1-9])(\s?)(-)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(-)(\s?)(\d{2}|\d{4})((\.|\,|\s|\))|\s*$)", "MDY", True),
            # M.D.Y (whitespace = true)
            (r"((\s)|(\())(0[1-9]|1[0-2]|[1-9])(\s?)(\.)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(\.)(\s?)(\d{2}|\d{4})((\.|\,|\s|\))|\s*$)", "MDY", True),
            # M/D/Y (whitespace = true)
            (r"((\s)|(\())(0[1-9]|1[0-2]|[1-9])(\s?)(\/)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(\/)(\s?)(\d{2}|\d{4})((\.|\,|\s|\))|\s*$)", "MDY", True),
            # M-D-Y (whitespace = false)
            (r"((\s*)|(\())(0[1-9]|1[0-2]|[1-9])(\s?)(-)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(-)(\s?)(\d{2}|\d{4})((\.|\,|\s|\))|\s*$)", "MDY", False),
            # M.D.Y (whitespace = false)
            (r"((\s*)|(\())(0[1-9]|1[0-2]|[1-9])(\s?)(\.)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(\.)(\s?)(\d{2}|\d{4})((\.|\,|\s|\))|\s*$)", "MDY", False),
            # M/D/Y (whitespace = false)
            (r"((\s*)|(\())(0[1-9]|1[0-2]|[1-9])(\s?)(\/)(\s?)(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(\/)(\s?)(\d{2}|\d{4})((\.|\,|\s|\))|\s*$)", "MDY", False)
        ]
        # mit()
        #((\s*)|(\())(0[1-9]|[12][0-9]|3[01]|[1-9])(\s?)(\.)(\s?)(0[1-9]|1[0-2])(\s?)(\.)(\s?)(\d{4})((\.|\,|\s|\))|\s*$)

        res = None
        found_one_date = False
        # v1.09: OCR error tolerance for numeric dates. Match against a per-line
        # copy in which (a) common letter/digit confusions (O->0, l->1, A->4,
        # S->5, B->8 ...) and (b) separator confusions (comma->dot, en/em/minus
        # dashes->hyphen) are normalised, so misread numeric dates like
        # "Ol.07.2O26", "2O26-07-15", "1,7,2026" or "2026\u201307\u201315" are
        # recovered. str.translate is 1:1, so positions/lengths are unchanged and
        # start_pos stays valid. This is scoped to the numeric pass only; the
        # alpha month search keeps using the original act_line, and the
        # shell-side tag search is not affected at all. The existing positional
        # regexes (day 01-31, month 01-12) plus year-range/blacklist filtering
        # reject invalid normalised candidates (e.g. "AO.07.2026" -> "40.07.2026").
        norm_line = act_line.translate(_OCR_DIGIT_CONFUSABLES).translate(_OCR_SEPARATOR_CONFUSABLES)
        # Try patterns in the locale's preferred DATE_ORDER first. This mainly
        # influences which date ends up first in self.founddatelist (relevant
        # for the non-nearest "first found" mode). Ambiguous matches are
        # resolved per-order in _effective_date_order so the DMY and MDY
        # patterns converge on the same date and are de-duplicated by
        # check_blacklist.
        regexlist = sorted(
            regexlist,
            key=lambda r: self.date_orders.index(r[1]) if r[1] in self.date_orders else len(self.date_orders)
        )
        for single_regex in regexlist:

            res = None
            start_pos = 0
            while start_pos < len(norm_line):
                res = re.search(single_regex[0], norm_line[start_pos:])
                if res:
                    is_regex_with_whitespace = single_regex[2]
                    if res.start() != start_pos and start_pos == 0 and not is_regex_with_whitespace:
                        start_pos = start_pos + res.end()
                        break

                    # Resolve ambiguous numeric dates (e.g. 02.07.2026) via the
                    # >12 rule and the locale's DATE_ORDER priority instead of
                    # blindly trusting the pattern's nominal order.
                    eff_order = self._effective_date_order(single_regex[1], res.group(0))
                    settings_str = {'TIMEZONE': 'CEST', 'DATE_ORDER': eff_order}
                    if self.check_year_range(res, settings_str):  # add complete settings here
                        self.check_blacklist(res, settings_str)
                        found_one_date = True
                    start_pos = start_pos + res.end()
                    # break
                if not res:
                    break

#        found_one_date = False
#        start_pos = 0
#        while start_pos < len(act_line):
#            # start_pos = 0
#            # while start_pos < max_len:
#            res = None
#            for single_regex in regexlist:
#                res = re.search(single_regex[0], act_line[start_pos:])
#                if res:
#                    is_regex_with_ws = single_regex[2]
#                    if res.start() != start_pos and start_pos == 0 and not is_regex_with_ws:
#                        start_pos = start_pos + res.end()
#                        break

#                    settings_str = {'TIMEZONE': 'CEST', 'DATE_ORDER': single_regex[1]}
#                    if self.check_year_range(res, settings_str):                    # add complete settings here
#                        self.check_blacklist(res, settings_str)
#                        found_one_date = True
#                    start_pos = start_pos + res.end()
#                    break
#            if not res:
#                break

        return found_one_date
        
    def searchnearestdate(self):
        """
        get actual date
        sort found date list and return the nearest date that is not in the future
        """
        # find nearest day from today that is not in the future
        datenow = datetime.datetime.now()

        logging.info(f'start searchnearest')
        logging.debug(f'datelist not  ordered')
        for singleDate in self.founddatelist:
            logging.debug(f'{singleDate}')

        self.founddatelist.sort(reverse=True)
        logging.debug(f'date now')
        logging.debug(f'{datenow}')

        logging.debug(f'datelist ordered')
        for singleDate in self.founddatelist:
            logging.debug(f'{singleDate}')

        for actdate in self.founddatelist:
            if actdate <= datenow:
                logging.info(f'end searchnearest')
                return actdate

        logging.info(f'end searchnearest')
        return None

    def search_alpha_numeric_dates(self, act_line):

        # Mai 2022
        # \s?(([a-zA-Z]{3}\.?)|([a-zA-ZäÄ]{4,12}))\s(\d{4}|\d{2})
        # 01. Mai 2022
        # \s(((0[1-9]|[12][0-9]|3[01]|[1-9])\.?)?)\s(([a-zA-Z]{3}\.?)|([a-zA-ZäÄ]{4,12}))\s(\d{4}|\d{2})


        # regex_long_date = r"\s?((([1-9{1}]|0[1-9]|[12][0-9]|3[01])\.?)\s?)(([a-zA-Z]{3}\.)|([a-zA-ZäÄ]{3,12}))\s+(\d{4}|\d{2})"
        # v1.08: month-name character class widened from German-only "a-zA-ZäÄ"
        # to _MONTH_LETTERS (common Latin-1 accented letters) so international
        # month names such as "février", "marzo", "giugno", "maio", "maart"
        # match. Locale resolution itself happens in check_year_range /
        # check_blacklist via self.langs (derived from the -l hint).
        regex_long_date = (r"\b((([1-9{1}]|0[1-9]|[12][0-9]|3[01])\.?)\s?)"
                           r"(([" + _MONTH_LETTERS + r"]{3}\.)|([" + _MONTH_LETTERS + r"]{3,12}))\s+(\d{4}|\d{2})")
        #regex_short_date = r"\s?(([a-zA-Z]{3}\.)|([a-zA-ZäÄ]{4,12}))\s(\d{4}|\d{2})"
        #regex_short_date = r"\s?(((((Jan)|(Feb)|(Mrz)|(Apr)|(Mai)|(Jun)|(Jul)|(Aug)|(Sep)|(Okt)|(Oct)|(Nov)|(Dez)|(Dec)))\.)|([a-zA-ZäÄ]{4,12}))\s+(\d{4}|\d{2})"
        regex_short_date = (r"\b(((((Jan)|(Feb)|(Mrz)|(Apr)|(Mai)|(Jun)|(Jul)|(Aug)|(Sep)|(Okt)|(Oct)|(Nov)|(Dez)|(Dec)))\.)|"
                            r"([" + _MONTH_LETTERS + r"]{4,12}))\s+(\d{4}|\d{2})")

        regex_list = [ regex_long_date, regex_short_date ]

        founddate = None
        found_something = False
        start_pos = 0
        found_dates_cnt = 0
        while start_pos < len(act_line):
            found_something = False
            result = None
            for single_regex in regex_list:
                # search for long alphanumeric dates 11. Oktober 2022
                result = re.search(single_regex, act_line[start_pos:], re.IGNORECASE)
                if result:
                    settings_str = {'TIMEZONE': 'CEST',
                                'REQUIRE_PARTS': ['month', 'year'],
                                'PREFER_DAY_OF_MONTH': 'first'}
                    if self.check_year_range(result, settings_str):  # add complete settings here
                        self.check_blacklist(result, settings_str)
                    start_pos += result.end()
            if not result:
                break

 
    def search_dates(self):
        """
        search for dates in self.fileWithTextFindings
        """
        found_one_date = None

        logging.info(f'Start searching for alphanumerical and numerical dates......')

        # Check values
        # valid: 0, 1900-2200
        # if set to 0 everything is allowed. otherwise min-max
        if self.minYear != 0 and self.maxYear != 0 and (self.minYear >= self.maxYear):
            logging.info(f'Parameter minYear > maxYear')
            return None

        if self.minYear != 0 and (self.minYear <= 1900 or self.minYear >= 2200):
            logging.info(f'use Parameter minYear = {self.minYear} invalid')
            return None

        if self.maxYear != 0 and (self.maxYear <= 1900 or self.maxYear >= 2200):
            logging.info(f'use Parameter maxYear = {self.maxYear} invalid')
            return None

        with open(self.fileWithTextFindings, 'r', encoding='UTF-8') as f:
            for line in f:
                logging.debug(f'Line from File: {line}')
                self.search_alpha_numeric_dates(line)
                self.search_all_numeric_dates(line)

            f.close()

        logging.info(f'finish searching for alphanumerical and numerical dates......')
        logging.info(f'found {len(self.founddatelist)} dates')

        if not self.founddatelist:
            logging.info('no dates found')
            return None
        else:
            if not self.searchnearest:
                return f"{self.founddatelist[0].year:04d}-{self.founddatelist[0].month:02d}-{self.founddatelist[0].day:02d}"
            else:
                # search dates that where nearest to today and not in future
                foundnearest = self.searchnearestdate()
                if foundnearest:
                    return f"{foundnearest.year:04d}-{foundnearest.month:02d}-{foundnearest.day:02d}"
                else:
                    return None


def main_fn():
    acceptedvalue = ['on', 'off']
    parser = argparse.ArgumentParser()
    parser.add_argument('-fileWithTextFindings', type=str)
    parser.add_argument('-dateBlackList', type=str, required=False)
    parser.add_argument('-searchnearest', type=str, required=False)

    # debug arguments
    parser.add_argument('-dbg_file', type=str, required=False)
    parser.add_argument('-dbg_lvl', type=int, required=False, choices=range(0, 3))
    parser.add_argument('-minYear', type=int, required=True)
    parser.add_argument('-maxYear', type=int, required=True)
    # Tesseract -l value (e.g. "deu+eng") used as a locale hint for international
    # date parsing. Optional for backward compatibility (older callers omit it).
    parser.add_argument('-lang', type=str, required=False)

    findDate = FindDates()
    try:
        args = parser.parse_args()
    except argparse.ArgumentError:
        print('Catching an argumentError', file=sys.stderr)

    if args.dbg_lvl:
        # 0 = aus, 1=standard, 2=debug
        findDate.dbg_lvl = args.dbg_lvl

    if args.dbg_file:
        dbg_file = Path(args.dbg_file)
        # if dbg_file.is_file():
        findDate.dbg_file = args.dbg_file

    if args.dbg_lvl >= 1:
        # and dbg_file.is_file():
        if args.dbg_lvl == 1:
            dbg_lvl = logging.INFO
        elif args.dbg_lvl == 0:
            dbg_lvl = logging.NOTSET
        else:
            dbg_lvl = logging.DEBUG

        logging.basicConfig(filename=findDate.dbg_file, filemode='a', format='%(asctime)s - %(message)s', level=dbg_lvl)
        logging.info('Date scanning started')
        logging.info(f'Version: {findDate.version}')

    #   if args.minYear and args.maxYear:
    logging.info(f'Parameter minYear = {args.minYear}')
    logging.info(f'Parameter maxYear = {args.maxYear}')
    findDate.minYear = args.minYear
    findDate.maxYear = args.maxYear

    # Resolve the Tesseract -l hint into dateparser languages + DATE_ORDER
    # priority. When the hint is absent or contains no usable language (e.g.
    # only "osd"), keep the previous German-centric default (['de']).
    if args.lang:
        logging.info(f'Parameter lang = {args.lang}')
        resolved_langs, resolved_orders = resolve_lang_hint(args.lang)
        if resolved_langs is not None:
            findDate.langs = resolved_langs
        if resolved_orders:
            findDate.date_orders = resolved_orders
    logging.info(f'resolved dateparser languages = {findDate.langs}')
    logging.info(f'resolved DATE_ORDER priority = {findDate.date_orders}')

    if args.searchnearest:
        logging.info(f'Parameter searchnearest = {args.searchnearest}')
        if args.searchnearest in acceptedvalue:
            # logging.info(f'Parameter searchnearest = {args.searchnearest}')
            logging.info(f'set searchnearest = {args.searchnearest}')
            findDate.setfindmode(args.searchnearest)
        else:
            logging.info(f'searchnearest invalid = {args.searchnearest}')

    if args.fileWithTextFindings:
        logging.info(f'Parameter fileWithTextFindings = {args.fileWithTextFindings}')
        findDate.add_file_with_text_findings(args.fileWithTextFindings)
    if args.dateBlackList:
        logging.info(f'Parameter dateBlackLIst = {args.dateBlackList}')
        findDate.add_black_list(args.dateBlackList)

    foundDate = findDate.search_dates()

    print(f"{foundDate}")
    if args.dbg_lvl >= 1:
        logging.info(f'found date {foundDate}')
        logging.info('Date scanning ended')

#testdateien/log.txt
if __name__ == '__main__':
    main_fn()
