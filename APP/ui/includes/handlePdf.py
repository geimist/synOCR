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
from datetime import datetime
import json


class HandlePdfErrorCode:
    ERROR_NO_ERROR = 0
    ERROR_PARAM_OUTPUTFILE_NOT_SET = 13
    ERROR_PARAM_INPUTFILE_NOT_SET = 6
    ERROR_INPUTFILE_NO_FILE = 7
    ERROR_INPUTFILE_NOT_READABLE = 8
    ERROR_PARAM_START_PAGE_NOT_SET = 3
    ERROR_PARAM_END_PAGE_NOT_SET = 4
    ERROR_START_END_PAGE_VALUES_GTH_PAGECNT = 9
    ERROR_START_END_PAGE_COMPLETE_DOC = 10
    ERROR_START_END_PAGE_VALUES = 12
    ERROR_PAGE_DELETE = 11
    ERROR_WRITE_OUTFILE = 14
    ERROR_ARG_PARSE = 1
    ERROR_PARAM_TASK_INVALID = 2
    ERROR_METADATA_INVALID = 15
    ERROR_PARAM_METADATA_NOT_SET = 16
    ERROR_PARAM_NOT_A_KNOWN_KEY = 17



class HandlePdf:

# -dbg_lvl 1 -dbg_file log.txt -task split -inputFile 2023-03-24_#Rechnung#Sbk#Versicherung_20230324_1241_zahnersatz.pdf -startPage 1  -endPage 9  -outputFile 'outputFile.pdf'
# -dbg_lvl 1 -dbg_file log.txt -task metadate -inputFile 2023-03-24_#Rechnung#Sbk#Versicherung_20230324_1241_zahnersatz.pdf -outputFile 'outputFile.pdf' -metaData "{'/Author': 'John Doe', '/Keywords': 'Versicherung Allianz, KFZ, KFZ - Versicherung', '/CreationDate': 'D:20221108', '/CreatorTool': 'synOCR 1.022' }"
# '{"/Author": "John Doe", "/Keywords": "Versicherung Allianz, KFZ, KFZ - Versicherung", "/CreationDate": "D:20221108", "/CreatorTool": "synOCR 1.022" }'

    def __init__(self, dbg_lvl_int, dbg_file_str):
        self.start_page = 0
        self.end_page = 0
        self.output_file = None
        self.input_file = None
        self.input_pdf = None
        self.page_cnt = 0
        self.task = None
        self.dbg_lvl = dbg_lvl_int
        self.dbg_file = dbg_file_str
        self.version = '0.1'
        self.creator_str = None
        self.meta_data = None
        self.meta_data_dict = None

        if self.dbg_lvl >= 1:
            # and dbg_file.is_file():
            if self.dbg_lvl == 1:
                self.dbg_lvl = logging.INFO
            elif self.dbg_lvl == 0:
                self.dbg_lvl = logging.NOTSET
            else:
                self.dbg_lvl = logging.DEBUG

            # logging.basicConfig(filename=self.dbg_file, filemode='a', format='%(asctime)s - %(levelname)s - %(message)s',
            #                    level=self.dbg_lvl)
            # self.logger_obj = logging.getLogger()
            # self.logger_obj.setLevel(self.dbg_lvl)

            # Create a custom logger
            self.logger_obj = logging.getLogger(__name__)

            # Create handlers
            # c_handler = logging.StreamHandler()
            f_handler = logging.FileHandler(self.dbg_file)
            # c_handler.setLevel(logging.WARNING)
            # f_handler.setLevel(self.dbg_lvl)

            # Create formatters and add it to handlers
            # c_format = logging.Formatter('%(name)s - %(levelname)s - %(message)s')
            f_format = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
            # c_handler.setFormatter(c_format)
            f_handler.setFormatter(f_format)

            # Add handlers to the logger
            # logger.addHandler(c_handler)
            self.logger_obj.addHandler(f_handler)

            # self.logger_obj.warning('This is a warning')
            # self.logger_obj.error('This is an error')
            self.logger_obj.setLevel(self.dbg_lvl)

            self.logger_obj.info('HandlePdf started')
            self.logger_obj.info(f'Version: {self.version}')

    def split_page(self):
        self.logger_obj.info('>>>>>> split_page started')

        self.page_cnt = len(self.input_pdf.pages)
        self.logger_obj.info(f'page count = {self.page_cnt}')
        self.logger_obj.info(f'startPage({self.start_page}), endPage({self.end_page})')
        if self.start_page > self.page_cnt or self.end_page > self.page_cnt:
            self.logger_obj.error(
                f'startPage({self.start_page}) or endPage({self.end_page}) > page count({self.page_cnt})!!!')
            return HandlePdfErrorCode.ERROR_START_END_PAGE_VALUES_GTH_PAGECNT

        if self.start_page == 1 and self.end_page == self.page_cnt:
            self.logger_obj.error(f'startPage({self.start_page}), endPage({self.end_page}) = complete document!!!')
            return HandlePdfErrorCode.ERROR_START_END_PAGE_COMPLETE_DOC

        try:
            if self.start_page == 1 and self.end_page != self.page_cnt:
                # pages above endpage
                nr_pages_to_delete = self.page_cnt - self.end_page
                self.logger_obj.info(f'remove pages({nr_pages_to_delete}) above endPage({self.end_page})')
                for _ in range(nr_pages_to_delete):
                    del self.input_pdf.pages[-1]

            elif self.start_page != 1 and self.end_page == self.page_cnt:
                # pages below startpage
                nr_pages_to_delete = self.start_page - 1
                self.logger_obj.info(f'remove pages({nr_pages_to_delete}) below startPage({self.start_page})')
                for _ in range(nr_pages_to_delete):
                    del self.input_pdf.pages[0]

            elif self.start_page != 1 and self.end_page != self.page_cnt:
                # pages above endpage
                nr_pages_to_delete = self.page_cnt - self.end_page
                self.logger_obj.info(f'remove pages({nr_pages_to_delete}) above endPage({self.end_page})')
                for _ in range(nr_pages_to_delete):
                    del self.input_pdf.pages[-1]

                # pages below startpage
                nr_pages_to_delete = self.start_page - 1
                self.logger_obj.info(f'remove pages({nr_pages_to_delete}) below startPage({self.start_page})')
                for _ in range(nr_pages_to_delete):
                    del self.input_pdf.pages[0]
            else:
                self.logger_obj.error(f'error start and end page!!!')
                return HandlePdfErrorCode.ERROR_START_END_PAGE_VALUES
        except Exception as ex:
            self.logger_obj.error(f'execption caused by page delete!!!')
            return HandlePdfErrorCode.ERROR_PAGE_DELETE

        # write outfile
        try:
            self.logger_obj.info(f'save pdf to file ({self.output_file})')
            self.input_pdf.save(self.output_file)
        except Exception as ex:
            self.logger_obj.error(f'execption caused by pdf save!!!')
            return HandlePdfErrorCode.ERROR_WRITE_OUTFILE

        self.logger_obj.info('<<<<<< split_page ended')
        return 0

    def open_pdf(self):
        self.logger_obj.info('>>>>>> open_pdf started')
        # try to read pdf
        try:
            self.input_pdf = Pdf.open(self.input_file)
        except Exception as ex:
            return HandlePdfErrorCode.ERROR_INPUTFILE_NOT_READABLE

        self.logger_obj.info('<<<<<< open_pdf ended')
        return 0

    def write_metadata(self):
        self.logger_obj.info('>>>>> write meta_data ended')
        # self.logger_obj.info(meta['xmp:CreatorTool'])
        #meta_data_str = {'/Author': 'John Doe',
        #                 '/Keywords': 'Versicherung Allianz, KFZ, KFZ - Versicherung',
        #                 '/CreationDate': 'D:20221108',
        #                 '/CreatorTool': 'synOCR 1.022'
        #                 }

        self.logger_obj.debug('old meta_data....')
        self._print_metadata()

        with self.input_pdf.open_metadata() as meta:

            if '/CreatorTool' in self.meta_data_dict:
                if len(self.meta_data_dict['/CreatorTool']):
                    meta['xmp:CreatorTool'] = self.meta_data_dict['/CreatorTool']

            if '/Keywords' in self.meta_data_dict:
                if len(self.meta_data_dict['/Keywords']):
                    meta['pdf:Keywords'] = self.meta_data_dict['/Keywords']

            if '/CreationDate' in self.meta_data_dict:
                if len(self.meta_data_dict['/CreationDate']):
                    # '/CreationDate': 'D:20221108'
                    #YYYY - MM - DDThh: mm:ss
                    date_str_lst = self.meta_data_dict['/CreationDate'].split(':')
                    if len(date_str_lst) == 2:
                        datetime_object = datetime.strptime(date_str_lst[-1], '%Y%m%d').date()
                        new_date = f"{datetime_object.year}-{datetime_object.month:02d}-{datetime_object.day:02d}T00:00:00"
                        meta['xmp:CreateDate'] = new_date
                        meta['xmp:ModifyDate'] = new_date

            if '/Author' in self.meta_data_dict:
                if len(self.meta_data_dict['/Author']):
                    meta['dc:contributor'] = self.meta_data_dict['/Author']
                    meta['pdf:Author'] = self.meta_data_dict['/Author']

           # meta['pdf:Producer'] = 'pikepdf'

        self.logger_obj.debug('new meta_data....')
        self.logger_obj.debug(f'{meta}')


        # write outfile
        try:
            self.logger_obj.info(f'save pdf to file ({self.output_file})')
            self.input_pdf.save(self.output_file)
        except Exception as ex:
            self.logger_obj.error(f'execption caused by pdf save!!!')
            return HandlePdfErrorCode.ERROR_WRITE_OUTFILE

        self.logger_obj.info('<<<<<< write meta_data ended')
        return 0

    def set_task_split_parameter(self, input_file: str, output_file: str, start_page: int, end_page: int):
        self.logger_obj.info(f'set_task_split_parameter(input_file={input_file}, output_file={output_file},\
                    start_page={start_page}, end_page={end_page})')

        if output_file is None:
            self.logger_obj.error(f'output_file not set!!')
            return HandlePdfErrorCode.ERROR_PARAM_OUTPUTFILE_NOT_SET

        # check if inputfile exists
        if input_file is None:
            self.logger_obj.error(f'input_file not set!!')
            return HandlePdfErrorCode.ERROR_PARAM_INPUTFILE_NOT_SET

        test_file = Path(input_file)
        if not test_file.is_file():
            self.logger_obj.error(f'inputFile {test_file} is no file!!')
            return HandlePdfErrorCode.ERROR_INPUTFILE_NO_FILE

        # check startpage, endpage
        if start_page is None:
            self.logger_obj.error(f'startPage is not set!!')
            return HandlePdfErrorCode.ERROR_PARAM_START_PAGE_NOT_SET
        if end_page is None:
            self.logger_obj.error(f'endPage is not set!!')
            return HandlePdfErrorCode.ERROR_PARAM_END_PAGE_NOT_SET

        if start_page > end_page:
            self.logger_obj.error(f'startPage({start_page}) > end_page({end_page})!!')
            return HandlePdfErrorCode.ERROR_START_END_PAGE_VALUES
        if start_page <= 0 or end_page <= 0:
            self.logger_obj.error(f'startPage({start_page}) or end_page({end_page}) <= 0!!')
            return HandlePdfErrorCode.ERROR_START_END_PAGE_VALUES

        self.start_page = start_page
        self.end_page = end_page
        self.output_file = output_file
        self.input_file = input_file

        self.logger_obj.info('<<<<<< set_task_split_parameter ended')
        return 0

    def set_task_metadata_parameter(self, input_file: str, output_file: str, meta_data_str: str):
        self.logger_obj.info(f'set_task_metadata_parameter(input_file={input_file}, output_file={output_file},\
                    meta_data_str={meta_data_str})')

        if output_file is None:
            self.logger_obj.error(f'output_file not set!!')
            return HandlePdfErrorCode.ERROR_PARAM_OUTPUTFILE_NOT_SET

        # check if inputfile exists
        if input_file is None:
            self.logger_obj.error(f'input_file not set!!')
            return HandlePdfErrorCode.ERROR_PARAM_INPUTFILE_NOT_SET

        test_file = Path(input_file)
        if not test_file.is_file():
            self.logger_obj.error(f'inputFile {test_file} is no file!!')
            return HandlePdfErrorCode.ERROR_INPUTFILE_NO_FILE

        if input_file is None:
            self.logger_obj.error(f'metaData not set!!')
            return HandlePdfErrorCode.ERROR_PARAM_METADATA_NOT_SET

        meta_data_dct = json.loads(meta_data_str.replace('\'', '\"'))

        if not isinstance(meta_data_dct, dict):
            self.logger_obj.error(f'meta_data_str {meta_data_str} is no dict!!')
            return HandlePdfErrorCode.ERROR_METADATA_INVALID

        # check for known keys
        known_keys_list = ('/Author', '/Keywords', '/CreationDate', '/CreatorTool')

        for dict_key in meta_data_dct.keys():
            if dict_key not in known_keys_list:
                self.logger_obj.error(f'found key{dict_key} not in known key list{known_keys_list}!!')
                return HandlePdfErrorCode.ERROR_PARAM_NOT_A_KNOWN_KEY

        self.meta_data_dict = meta_data_dct
        self.output_file = output_file
        self.input_file = input_file

        self.logger_obj.info('<<<<<< set_task_meta_data_parameter ended')
        return 0

    def _print_metadata(self):
        self.logger_obj.debug(f'>>>>> log metadata >>>>>)')

        self.meta_data = self.input_pdf.open_metadata()

        self.logger_obj.debug(f'{self.meta_data}')
        print(f"{self.meta_data}")

        self.logger_obj.debug(f'<<<<< log metadata <<<<<)')

        return 0


def main_fn():
    parser = argparse.ArgumentParser()
    parser.add_argument('-task', type=str, required=True)
    parser.add_argument('-inputFile', type=str, required=True)
    parser.add_argument('-dbg_file', type=str, required=True)
    parser.add_argument('-dbg_lvl', type=int, required=True, choices=range(0, 3))

    # args for page splitt
    parser.add_argument('-startPage', type=int, required=False)
    parser.add_argument('-endPage', type=int, required=False)
    parser.add_argument('-outputFile', type=str, required=False)

    # args for write metadata
    #parser.add_argument('-outputFile', type=str, required=False)
    parser.add_argument('-metaData', type=str, required=False)

    try:
        args = parser.parse_args()
    except argparse.ArgumentError:
        return HandlePdfErrorCode.ERROR_ARG_PARSE

    pdf_obj = HandlePdf(args.dbg_lvl, args.dbg_file)
    pdf_obj.logger_obj.info(f'Task={args.task}')
    task_lower = str(args.task).lower()
    if task_lower == 'split':
        error_code = pdf_obj.set_task_split_parameter(args.inputFile, args.outputFile, args.startPage, args.endPage)
    elif task_lower == 'metadata':
        error_code = pdf_obj.set_task_metadata_parameter(args.inputFile, args.outputFile, args.metaData)
        # return HandlePdfErrorCode.ERROR_PARAM_TASK_INVALID
    else:
        pdf_obj.logger_obj.error(f'Task={task_lower} invalid!')
        return HandlePdfErrorCode.ERROR_PARAM_TASK_INVALID

    if error_code:
        return error_code

    error_code = pdf_obj.open_pdf()
    if error_code:
        return error_code

    if task_lower == 'split':
        error_code = pdf_obj.split_page()
    else:
        error_code = pdf_obj.write_metadata()

    return error_code


if __name__ == '__main__':
    test_str = {'/Author': 'John Doe',
                '/Keywords': 'Versicherung Allianz, KFZ, KFZ - Versicherung',
                '/CreationDate': 'D:20221108',
                '/CreatorTool': 'synOCR 1.022'
                }

    test_str1 = {'/Author': '',
                '/Keywords': 'Versicherung Allianz, KFZ, KFZ - Versicherung',
                '/CreationDate': 'D:20221108',
                '/CreatorTool': 'synOCR 1.022'
                }

    for key in test_str1.keys():
        if not len(test_str1[key]):
            print("empty")

    return_value = main_fn()

    print(return_value)
