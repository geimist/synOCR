#######################################################################
#  Parse Textfiles for valid dates.
#  Check if dates were not listed in a blacklist and/or were not in the future
#  Actually following date formats were supported
#  DD-/.MM-/.YYYY  / means or
#  returnvalue = founddate YYYY-MM-DD or None
#
#  Author: gthorsten
#  Version:
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
        self.version = '1.00'
        self.found_date_cnt = 0
                       

        now = datetime.datetime.now()
        self.year_now = now.year
        self.minYear = 0
        self.maxYear = 0

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

    def splitt_dates(self, date_string):
        """
        search in date_string for numerical date-values used as blacklist dates
        :param date_string:
        :return: founddatelist contains a list of datetime objects
        """
        founddatelist = []
        regexlist = [
            r"(0[1-9]|[12][0-9]|3[01])(-|\.)(0[1-9]|1[0-2])(-|\.)\d{4}",  # DDMMYYY
            r"\d{4}(-|\.)(0[1-9]|1[0-2])(-|\.)(0[1-9]|[12][0-9]|3[01])"  # YYYYMMDD
        ]

        for singleregex in regexlist:
            startpos = 0
            while startpos < len(date_string):
                result = re.search(singleregex, date_string[startpos:])
                if result:  # , settings={'DATE_ORDER': 'DMY'}
                    parseresult = dateparser.parse(result.group(0), settings={'DATE_ORDER': 'DMY', 'TIMEZONE': 'CEST'})
                    if not parseresult:
                        parseresult = dateparser.parse(result.group(0),
                                                       settings={'DATE_ORDER': 'YMD', 'TIMEZONE': 'CEST'})

                    if parseresult:
                        # founddatelist.append(f"{parseresult.day:02d}.{parseresult.month:02d}.{parseresult.year:4d}")
                        founddatelist.append(parseresult)
                    startpos += result.end()
                else:
                    break
        return founddatelist

    def add_black_list(self, dateblacklist):
        """
        splitt string dateblacklist in datetime objects
        :param dateblacklist:
        :return:
        """
        logging.info('start checking blacklist')
        blackListDates = self.splitt_dates(dateblacklist)
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
        date_obj = dateparser.parse(regex_result, settings=settings_str)
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
        date_obj = dateparser.parse(regex_result.group(0), settings=settings_str)
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

    def search_all_numeric_dates(self, act_line):
        """
        Search for numeric dates in self.searchtextstr
        return value is always an list. empty if no date found, otherwise contains a list of datetime objects
        """
        founddate = None
        # reg für zahlendatums
        # 12.12.2022
        # 12.12.20     (DD.MM.YY)
        # (0[1-9]|[12][0-9]|3[01])(-|\.)(0[1-9]|1[0-2])(-|\.)\d{4}(\s|\.|\,)
        # DD-|.|/MM-|.|/YYYY
        # DD-|.|/MM-|.|/YY
        #
        # !!!!! \s?(0[1-9]|[12][0-9]|3[01])(\s?)(-|\.|\/)(\s?)(0[1-9]|1[0-2])(\s?)(-|\.|\/)(\s?)(\d{4}|\d{2})(\s|\.|\,)
        # /(0[1-9]|[12][0-9]|3[01])(-|\.|\/)(0[1-9]|1[0-2])(-|\.|\/)\d{4}/gm
        # YYYY-|.|/MM-|.|/DD
        # YY-|.|/MM-|.|/DD
        #
        # !!!!! \s?(((\d{4})(\s?)(-|\.|\/)(\s?))|((\d{2})(\s?)(-|\.|\/)(\s?)))(0[1-9]|1[0-2])(\s?)(-|\.|\/)(\s?)(0[1-9]|[12][0-9]|3[01])(\.|\,|\s)

        max_len = len(self.searchtextstr)

        regexlist = [
            r"\s(0[1-9]|[12][0-9]|3[01])(\s?)(-)(\s?)(0[1-9]|1[0-2])(\s?)(-)(\s?)(\d{4}|\d{2})(\s|\.|\,)",  # D-M-Y
            r"\s(0[1-9]|[12][0-9]|3[01])(\s?)(\.)(\s?)(0[1-9]|1[0-2])(\s?)(\.)(\s?)(\d{4}|\d{2})(\s|\.|\,)",  # D.M.Y
            r"\s(0[1-9]|[12][0-9]|3[01])(\s?)(\/)(\s?)(0[1-9]|1[0-2])(\s?)(\/)(\s?)(\d{4}|\d{2})(\s|\.|\,)",  # D/M/Y
            r"\s(((\d{4})(\s?)(-)(\s?))|((\d{2})(\s?)(-)(\s?)))(0[1-9]|1[0-2])(\s?)(-)(\s?)(0[1-9]|[12][0-9]|3[01])(\.|\,|\s)",  # Y-M-D
            r"\s(((\d{4})(\s?)(\.)(\s?))|((\d{2})(\s?)(\.)(\s?)))(0[1-9]|1[0-2])(\s?)(\.)(\s?)(0[1-9]|[12][0-9]|3[01])(\.|\,|\s)",
            # Y.M.D
            r"\s(((\d{4})(\s?)(\/)(\s?))|((\d{2})(\s?)(\/)(\s?)))(0[1-9]|1[0-2])(\s?)(\/)(\s?)(0[1-9]|[12][0-9]|3[01])(\.|\,|\s)"
            # Y/M/D
        ]

        start_pos = 0
        while start_pos < len(act_line):
            # start_pos = 0
            # while start_pos < max_len:
            res = None
            for single_regex in regexlist:
                res = re.search(single_regex, act_line[start_pos:])
                if res:
                    settings_str = {'TIMEZONE': 'CEST', 'DATE_ORDER': 'DMY'}
                    if self.check_year_range(res, settings_str):                    # add complete settings here
                        self.check_blacklist(res, settings_str)
                    start_pos = start_pos + res.end()
            if not res:
                break

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
        # \s(((0[1-9]|[12][0-9]|3[01])\.?)?)\s(([a-zA-Z]{3}\.?)|([a-zA-ZäÄ]{4,12}))\s(\d{4}|\d{2})


        regex_long_date = r"\s?((([1-9{1}]|0[1-9]|[12][0-9]|3[01])\.?)\s?)(([a-zA-Z]{3}\.)|([a-zA-ZäÄ]{4,12}))\s(\d{4}|\d{2})"
        regex_short_date = r"\s?(([a-zA-Z]{3}\.)|([a-zA-ZäÄ]{4,12}))\s(\d{4}|\d{2})"

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
                result = re.search(single_regex, act_line[start_pos:])
                if result:
                    settings_str = {'TIMEZONE': 'CEST',
                                'REQUIRE_PARTS': ['month', 'year'],
                                'PREFER_DAY_OF_MONTH': 'first'}
                    if self.check_year_range(result, settings_str):  # add complete settings here
                        self.check_blacklist(result, settings_str)
                    start_pos += result.end()
            if not result:
                break

    def dummy(self, x, y):
        return x + y

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


if __name__ == '__main__':
    main_fn()
