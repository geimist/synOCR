# main sourcecode from: https://github.com/baltpeter/scanprep/blob/master/scanprep/scanprep.py
import argparse
import fitz
from PIL import Image, ImageFilter, ImageStat
import numpy as np
import os
import pathlib

# Algorithm inspired by: https://dsp.stackexchange.com/a/48837
def page_is_empty(img, threshold_offset, lr_margin_ratio, tb_margin_ratio, max_filter_size, min_filter_size, black_pixel_ratio, page_text):
    threshold = np.mean(ImageStat.Stat(img).mean) - threshold_offset
    img = img.convert('L').point(lambda x: 255 if x > threshold else 0)

    # Staples, folds, punch holes et al. tend to be confined to the left and right margin, so we crop off 10% there.
    # Also, we crop off 5% at the top and bottom to get rid of the page borders.
    lr_margin = img.width * lr_margin_ratio
    tb_margin = img.height * tb_margin_ratio
    img = img.crop((lr_margin, tb_margin, img.width - lr_margin, img.height - tb_margin))

    # Use erosion and dilation to get rid of small specks but make actual text/content more significant.
    img = img.filter(ImageFilter.MaxFilter(max_filter_size))
    img = img.filter(ImageFilter.MinFilter(min_filter_size))

    white_pixels = np.count_nonzero(img)
    total_pixels = img.size[0] * img.size[1]
    ratio = (total_pixels - white_pixels) / total_pixels

    # Check if the page contains any text
    if len(page_text.strip()) > 0:
        return False

    return ratio < black_pixel_ratio

def get_new_docs_pages(doc, remove_blank, threshold_offset, lr_margin_ratio, tb_margin_ratio, max_filter_size, min_filter_size, black_pixel_ratio):
    pages = []

    for page in doc:
        pixmap = page.getPixmap()
        img = Image.frombytes("RGB", (pixmap.width, pixmap.height), pixmap.samples)
        page_text = page.getText("text")

        if remove_blank and page_is_empty(img, threshold_offset, lr_margin_ratio, tb_margin_ratio, max_filter_size, min_filter_size, black_pixel_ratio, page_text):
            continue

        pages.append(page.number)

    return pages

def emit_new_document(doc, filename, out_dir, remove_blank, threshold_offset, lr_margin_ratio, tb_margin_ratio, max_filter_size, min_filter_size, black_pixel_ratio):
    pathlib.Path(out_dir).mkdir(parents=True, exist_ok=True)

    pages = get_new_docs_pages(doc, remove_blank, threshold_offset, lr_margin_ratio, tb_margin_ratio, max_filter_size, min_filter_size, black_pixel_ratio)
    new_doc = fitz.open()  # Will create a new, blank document.
    for page_no in pages:
        new_doc.insertPDF(doc, from_page=page_no, to_page=page_no)
    new_doc.save(os.path.join(out_dir, filename))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('input_pdf', help='The PDF document to process.')
    parser.add_argument('output_dir', help='The directory where the output document will be saved.', nargs='?', default=os.getcwd())
    parser.add_argument('--no-blank-removal', dest='remove_blank', action='store_false', help='Do not remove empty pages from the output.')
    parser.add_argument('--threshold', type=float, default=-50, help='Threshold offset for empty page detection.')
    parser.add_argument('--width-crop', type=float, default=0.10, help='Percentage of width to crop from the sides.')
    parser.add_argument('--height-crop', type=float, default=0.05, help='Percentage of height to crop from the top and bottom.')
    parser.add_argument('--max-filter', type=int, default=1, help='Size of the MaxFilter used for noise reduction.')
    parser.add_argument('--min-filter', type=int, default=3, help='Size of the MinFilter used for noise reduction.')
    parser.add_argument('--black-pixel-ratio', type=float, default=0.005, help='Ratio of black pixels to classify a page as non-empty.')
    parser.set_defaults(remove_blank=True)
    args = parser.parse_args()

    emit_new_document(
        fitz.open(os.path.abspath(args.input_pdf)),
        os.path.basename(args.input_pdf),
        os.path.abspath(args.output_dir),
        args.remove_blank,
        args.threshold,
        args.width_crop,
        args.height_crop,
        args.max_filter,
        args.min_filter,
        args.black_pixel_ratio
    )

if __name__ == '__main__':
    main()
