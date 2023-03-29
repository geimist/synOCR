#######################################################################
#  Split pdf files to separate pasges
#  parameter:
#  -task:         split, writeMetadata(not implemented)
#  -inputFile:    input pdf filename (with path)
#  -outputFile:   output pdf filename (with path)
#  -startPage:    first page from inputfile transfered to outputfile (1 based)
#  -endPage:      last page ( 1 based )
#  -dbg_file:     filename to write debug info
#  -dbg_lvl:      debug level (1=info, 2=debug, 0=0ff)
#
#
# ExampleCall:
# handlePdf.py -dbg_lvl 1 -dbg_file log.txt -task split -inputFile TestDocA.pdf -startPage 1  -endPage 2  -outputFile outputFile.pdf
#
#
#  Author: gthorsten
#  Version:
#
#     0.1, 26.03.2023
#           initial version
#
#
#


from pikepdf import Pdf
import argparse
from pathlib import Path
import logging


class HandlePdf:

    ERROR_PARAM_OUTPUTFILE_NOT_SET = 13
    ERROR_PARAM_INPUTFILE_NOT_SET = 6
    ERROR_INPUTFILE_NO_FILE = 7
    ERROR_INPUTFILE_NOT_READABLE = 8
    ERROR_PARAM_START_PAGE_NOT_SET = 3
    ERROR_PARAM_START_END_NOT_SET = 4
    ERROR_START_END_PAGE_VALUES_GTH_PAGECNT = 9
    ERROR_START_END_PAGE_COMPLETE_DOC = 10
    ERROR_START_END_PAGE_VALUES = 12
    ERROR_PAGE_DELETE = 11
    ERROR_WRITE_OUTFILE = 14
    ERROR_ARG_PARSE = 1
    ERROR_PARAM_TASK_INVALID = 2

    def __init__(self):
        self.start_page = 0
        self.end_page = 0
        self.output_file = None
        self.input_file = None
        self.input_pdf = None
        self.page_cnt = 0
        self.task = -1
        self.dbg_lvl = 0
        self.dbg_file = None
        self.version = '0.1'

    def split_page(self):
        logging.info('>>>>>> split_page started')

        self.page_cnt = len(self.input_pdf.pages)
        logging.info(f'page count = {self.page_cnt}')
        logging.info(f'startPage({self.start_page}), endPage({self.end_page})')
        if self.start_page > self.page_cnt or self.end_page > self.page_cnt:
            logging.error(f'startPage({self.start_page}) or endPage({self.end_page}) > page count({self.page_cnt})!!!')
            return HandlePdf.ERROR_START_END_PAGE_VALUES_GTH_PAGECNT

        if self.start_page == 1 and self.end_page == self.page_cnt:
            logging.error(f'startPage({self.start_page}), endPage({self.end_page}) = complete document!!!')
            return HandlePdf.ERROR_START_END_PAGE_COMPLETE_DOC

        try:
            if self.start_page == 1 and self.end_page != self.page_cnt:
                # pages above endpage
                nr_pages_to_delete = self.page_cnt - self.end_page
                logging.info(f'remove pages({nr_pages_to_delete}) above endPage({self.end_page})')
                for _ in range(nr_pages_to_delete):
                    del self.input_pdf.pages[-1]

            elif self.start_page != 1 and self.end_page == self.page_cnt:
                # pages below startpage
                nr_pages_to_delete = self.start_page - 1
                logging.info(f'remove pages({nr_pages_to_delete}) below startPage({self.start_page})')
                for _ in range(nr_pages_to_delete):
                    del self.input_pdf.pages[0]

            elif self.start_page != 1 and self.end_page != self.page_cnt:
                # pages above endpage
                nr_pages_to_delete = self.page_cnt - self.end_page
                logging.info(f'remove pages({nr_pages_to_delete}) above endPage({self.end_page})')
                for _ in range(nr_pages_to_delete):
                    del self.input_pdf.pages[-1]

                # pages below startpage
                nr_pages_to_delete = self.start_page - 1
                logging.info(f'remove pages({nr_pages_to_delete}) below startPage({self.start_page})')
                for _ in range(nr_pages_to_delete):
                    del self.input_pdf.pages[0]
            else:
                logging.error(f'error start and end page!!!')
                return HandlePdf.ERROR_START_END_PAGE_VALUES
        except Exception as ex:
            logging.error(f'execption caused by page delete!!!')
            return HandlePdf.ERROR_PAGE_DELETE

        # write outfile
        try:
            logging.info(f'save pdf to file ({self.output_file})')
            self.input_pdf.save( self.output_file)
        except Exception as ex:
            logging.error(f'execption caused by pdf save!!!')
            return HandlePdf.ERROR_WRITE_OUTFILE

        logging.info('<<<<<< split_page ended')
        return 0

    def parse_user_args(self, parser):
        # parser.add_argument('-inputFile', type=str, required=True)
        # parser.add_argument('-task', type=str, required=True)
        # args for page splitt
        # parser.add_argument('-startPage', type=int, required=False)
        # parser.add_argument('-endPage', type=int, required=False)
        # parser.add_argument('-outputFile', type=str, required=False)
        # parser.add_argument('-dbg_file', type=str, required=False)
        # parser.add_argument('-dbg_lvl', type=int, required=False, choices=range(0, 3))

        try:
            args = parser.parse_args()
        except argparse.ArgumentError:
            return HandlePdf.ERROR_ARG_PARSE

        if args.dbg_lvl is not None:
            # 0 = aus, 1=standard, 2=debug
            self.dbg_lvl = args.dbg_lvl

        if args.dbg_file is not None:
            # dbg_file = Path(args.dbg_file)
            # if dbg_file.is_file():
            self.dbg_file = Path(args.dbg_file)

        if self.dbg_lvl >= 1:
            # and dbg_file.is_file():
            if self.dbg_lvl == 1:
                dbg_lvl = logging.INFO
            elif self.dbg_lvl == 0:
                self.dbg_lvl = logging.NOTSET
            else:
                self.dbg_lvl = logging.DEBUG

            logging.basicConfig(filename=self.dbg_file, filemode='a', format='%(asctime)s - %(levelname)s - %(message)s',
                                level=self.dbg_lvl)
            logging.info('HandlePdf started')
            logging.info(f'Version: {self.version}')

        logging.info('>>>>>> parse_user_args started')

        self.task = str(args.task).lower()
        logging.info(f'task: {self.task}')
        logging.info(f'outfile: {args.outputFile}')
        logging.info(f'inputFile: {args.inputFile}')
        logging.info(f'startPage: {args.startPage}')
        logging.info(f'endPage: {args.endPage}')

        if args.outputFile is None:
            return HandlePdf.ERROR_PARAM_OUTPUTFILE_NOT_SET


        # check if inputfile existsv
        if args.inputFile is None:
            logging.error(f'inputFile not set!!')
            return HandlePdf.ERROR_PARAM_INPUTFILE_NOT_SET

        input_file = Path(args.inputFile)
        if not input_file.is_file():
            logging.error(f'inputFile {input_file} is no file!!')
            return HandlePdf.ERROR_INPUTFILE_NO_FILE

        if self.task == 'split':
            # check startpage, endpage
            if args.startPage is None:
                logging.error(f'startPage is not set!!')
                return HandlePdf.ERROR_PARAM_START_PAGE_NOT_SET
            if args.endPage is None:
                logging.error(f'endPage is not set!!')
                return HandlePdf.ERROR_PARAM_START_END_NOT_SET
            start_page = args.startPage
            end_page = args.endPage

            if start_page > end_page:
                logging.error(f'startPage({start_page}) > end_page({end_page})!!')
                return HandlePdf.ERROR_START_END_PAGE_VALUES
            if start_page <= 0 or end_page <= 0:
                logging.error(f'startPage({start_page}) or end_page({end_page}) <= 0!!')
                return HandlePdf.ERROR_START_END_PAGE_VALUES

            self.start_page = start_page
            self.end_page = end_page
            self.output_file = args.outputFile
            self.input_file = args.inputFile

            logging.info('<<<<<< parse_user_args ended')

    def open_pdf(self):
        logging.info('>>>>>> open_pdf started')
        # try to read pdf
        try:
            self.input_pdf = Pdf.open(self.input_file)
        except Exception as ex:
            return HandlePdf.ERROR_INPUTFILE_NOT_READABLE

        logging.info('<<<<<< open_pdf ended')

    def write_metadata(self):
        return 0

    def pdf_tasks(self):
        logging.info('>>>>>> pdf_tasks started')
        if self.task == 'split':
            error_code = self.open_pdf()
            error_code = self.split_page()
            logging.info('<<<<<< pdf_tasks ended')
            return error_code

        elif self.task == 'metadate':
            ret_metadata = self.write_metadata()
            logging.info('<<<<<< pdf_tasks ended')
            return ret_metadata
        else:
            logging.info('<<<<<< pdf_tasks ended')
            return HandlePdf.ERROR_PARAM_TASK_INVALID


def main_fn():
    parser = argparse.ArgumentParser()
    parser.add_argument('-task', type=str, required=True)
    parser.add_argument('-inputFile', type=str, required=True)
    parser.add_argument('-dbg_file', type=str, required=False)
    parser.add_argument('-dbg_lvl', type=int, required=False, choices=range(0, 3))

    #args for page splitt
    parser.add_argument('-startPage', type=int, required=False)
    parser.add_argument('-endPage', type=int, required=False)
    parser.add_argument('-outputFile', type=str, required=False)

    pdf_obj = HandlePdf()
    error_code = pdf_obj.parse_user_args(parser)
    if error_code:
        return error_code
    error_code = pdf_obj.open_pdf()
    if error_code:
        return error_code
    error_code = pdf_obj.split_page()
    return error_code


if __name__ == '__main__':

    return_value = main_fn()

    print( return_value )


