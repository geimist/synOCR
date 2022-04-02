#!/usr/local/bin/python3

#######################################################################
#  Parse Textfiles for valid dates.
#  Check if dates were not listed in a blacklist and/or were not in the future
#  Actually following date formats were supported
#  DD-/.MM-/.YYYY  / means or
#  returnvalue = founddate YYYY-MM-DD or None
#
#  Author: gthorsten
#  Version:
#     0.1, 24.03.2022
#     0.2, 01.04.2022
#          remove exit on error for call ArgumentParser(exit_on_error=False)
#
#
import datetime

from dateparser.search import search_dates
import dateparser.parser
import re
import os
import sys
import argparse

class FindDates:

    def __init__(self):
        self.fileWithTextFindings = None
        self.dateBlackList_YMD = []
        self.dateBlackList_DMY = []
        self.searchtextstr = None
        self.founddatelist = []
        self.searchnearest = False


    def setfindmode(self, searchnearest):
        if searchnearest.casefold() == "on":
            self.searchnearest = True

    def add_file_with_text_findings(self, filewithtextfindings):

        try:
            with open(filewithtextfindings) as f:
                self.searchtextstr = " ".join([line.rstrip() for line in f])
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
                    parseresult = dateparser.parse(result.group(0), settings={'DATE_ORDER': 'DMY', 'TIMEZONE': 'Europe/Berlin'})
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
        blackListDates = self.splitt_dates(dateblacklist)
        if blackListDates:
            for blackListDate in blackListDates:
                founddate = f"{blackListDate.year:04d}.{blackListDate.month:02d}.{blackListDate.day:02d}"
                #print(founddate)
                self.dateBlackList_YMD.append(founddate)
                founddate = f"{blackListDate.day:02d}.{blackListDate.month:02d}.{blackListDate.year:04d}"
                self.dateBlackList_DMY.append(founddate)

    def search_all_numeric_dates(self):
        """
        Search for numeric dates in self.searchtextstr
        return value is always an list. empty if no date found, otherwise contains a list of datetime objects
        """
        founddate = None
        # reg für zahlendatums
        # 12.12.2022
        # 12.12.20     (DD.MM.YY)

        #(0[1-9]|[12][0-9]|3[01])(-|\.)(0[1-9]|1[0-2])(-|\.)\d{4}(\s|\.|\,)
        # DD-|.|/MM-|.|/YYYY
        # DD-|.|/MM-|.|/YY
        #s(0[1-9]|[12][0-9]|3[01])(\s?)(-|\.|/)(\s?)(0[1-9]|1[0-2])(\s?)(-|\.|/)(\s?)(\d{4}|\d{2})(\s|\.|\,)
        #
        # YYYY-|.|/MM-|.|/DD
        #\s(((\d{4})(\s?)(-|\.|/)(\s?))|((\d{2})(\s?)(-|\.|/)(\s?)))(0[1-9]|1[0-2])(\s?)(-|\.|/)(\s?)(0[1-9]|[12][0-9]|3[01])(\.|\,|\s)


        regex = r"(0[1-9]|[12][0-9]|3[01])(-|\.)(0[1-9]|1[0-2])(-|\.)\d{4}"

        maxlen = len(self.searchtextstr)
        startpos = 0
        while startpos < maxlen:
            res = re.search(regex,self.searchtextstr[startpos:])
            if res:
                actValue = res.group(0)
                dateobj = dateparser.parse(actValue, settings={'TIMEZONE': 'Europe/Berlin','DATE_ORDER': 'DMY'})
                actValue = f"{dateobj.day:02d}.{dateobj.month:02d}.{dateobj.year:04d}"
                if len(self.dateBlackList_DMY):
                    if actValue not in self.dateBlackList_DMY:
                        self.founddatelist.append(dateobj)
                else:
                    self.founddatelist.append(dateobj)

                startpos = startpos + res.end()
                #Check if startpos > maxlen of searchstring
                if startpos > maxlen:
                    #return None
                    return self.founddatelist
            else:
                return self.founddatelist


    def searchnearestdate(self):
        """
        get actual date
        sort found date list and return the nearest date that is not in the future
        """
        # find nearest day from today that is not in the future
        datenow = datetime.datetime.now()
        self.founddatelist.sort(reverse=True)
        for actdate in self.founddatelist:
            if actdate <= datenow:
                return actdate
        return None

    def search_alpha_numeric_dates(self):
        founddate = None
        return founddate



    def search_dates(self):
        """
        search for dates in self.fileWithTextFindings
        """
        found_one_date = None

        self.search_all_numeric_dates()
        if not self.founddatelist:
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


if __name__ == '__main__':
    acceptedvalue = ['on','off']
    parser = argparse.ArgumentParser(exit_on_error=False)
    parser.add_argument('-fileWithTextFindings', type=str)
    parser.add_argument('-dateBlackList', type=str, required=False)
    parser.add_argument('-searchnearest', type=str, required=False)

    findDate = FindDates()
    # findDate.add_file_with_text_findings("searchdate.txt")
    # findDate.add_black_list("BlackList")
    try:
        args = parser.parse_args()
    except argparse.ArgumentError:
        print('Catching an argumentError', file=sys.stderr)

    if args.searchnearest:
        if args.searchnearest in acceptedvalue:
            findDate.setfindmode(args.searchnearest)

    if args.fileWithTextFindings:
        findDate.add_file_with_text_findings(args.fileWithTextFindings)
    if args.dateBlackList:
        findDate.add_black_list(args.dateBlackList)


    foundDate = findDate.search_dates()
    print(f"{foundDate}")

