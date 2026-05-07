#!/usr/bin/env python3

#############################################################################################
#   description:    Dieses Skript passt Kontrast/Schärfe von PDFs an und ermöglicht optional #
#                   eine 1-Bit-Schwarzweiß-Konvertierung.                                   #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/includes/color_adjustment.py   #
#   © 2025 by geimist                                                                       #
#############################################################################################

import fitz
from PIL import Image, ImageChops, ImageEnhance, ImageFilter
import io
import argparse
import sys
import os

def enhance_image(img, contrast=1.0, sharpness=1.0):
    """
    Verbessert die Bildqualität durch Kontrast- und Schärfeanpassung
    """
    if contrast != 1.0:
        contrast_enhancer = ImageEnhance.Contrast(img)
        img = contrast_enhancer.enhance(contrast)
    
    if sharpness != 1.0:
        sharpness_enhancer = ImageEnhance.Sharpness(img)
        img = sharpness_enhancer.enhance(sharpness)
    
    return img


def adaptive_window_size(dpi):
    """
    Ermittelt eine ungerade Fenstergröße für adaptive Schwellwerte.
    Die Größe skaliert mit der Renderauflösung, damit sich 150/300/600 DPI
    ähnlich verhalten.
    """
    size = max(15, min(121, int(round(dpi / 8))))
    return size if size % 2 else size + 1


def convert_image_to_bw(img, threshold, dpi, absolute_threshold=0):
    """
    Konvertiert ein Bild mit einer gleitenden lokalen Schwelle nach 1-Bit-SW.
    Der threshold-Wert bleibt kompatibel zur bisherigen Logik: höhere Werte
    machen mehr Pixel weiß und priorisieren kleinere, sauberere Ausgaben.
    absolute_threshold erhält sehr dunkle Vollflächen, z.B. in Logos.
    """
    img_gray = img.convert('L')
    window_size = adaptive_window_size(dpi)
    local_mean = img_gray.filter(ImageFilter.BoxBlur(window_size // 2))

    threshold_diff = ImageChops.subtract(img_gray, local_mean, offset=threshold)
    img_bw = threshold_diff.point(lambda value: 255 if value > 0 else 0)

    if absolute_threshold > 0:
        absolute_bw = img_gray.point(lambda value: 0 if value <= absolute_threshold else 255)
        img_bw = ImageChops.darker(img_bw, absolute_bw)

    no_dither = Image.Dither.NONE if hasattr(Image, 'Dither') else Image.NONE
    return img_bw.convert('1', dither=no_dither)


def convert_pdf_to_bw(input_path, output_path, threshold=None, dpi=300, contrast=1.0, sharpness=1.0, absolute_threshold=0):
    """
    Hauptfunktion für die PDF-Bearbeitung
    
    Returns:
        int: 0 = Erfolg, 1 = Fehler
    """
    temp_output = output_path + ".tmp"
    
    try:
        with fitz.open(input_path) as pdf_document:
            output_pdf = fitz.open()
            
            for page in pdf_document:
                if dpi:
                    zoom = max(dpi / 72, 1.0)  # Sicherer Zoom-Wert
                    matrix = fitz.Matrix(zoom, zoom)
                    pix = page.get_pixmap(matrix=matrix, colorspace=fitz.csRGB, alpha=False)
                else:
                    pix = page.get_pixmap(colorspace=fitz.csRGB, alpha=False)
                
                img_data = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
                img_enhanced = enhance_image(img_data, contrast, sharpness)
                
                if threshold is not None:
                    final_img = convert_image_to_bw(img_enhanced, threshold, dpi, absolute_threshold)
                else:
                    final_img = img_enhanced.convert('RGB')
                
                # Sichereres Handling des Bildbuffers
                with io.BytesIO() as img_bytes:
                    final_img.save(img_bytes, format='PNG', optimize=True)
                    img_bytes.seek(0)
                    new_page = output_pdf.new_page(width=page.rect.width, height=page.rect.height)
                    new_page.insert_image(new_page.rect, stream=img_bytes.getvalue())
                    img_bytes.flush()  # Explizites Leeren des Buffers
            
            # Temporäre Ausgabe und atomares Umbenennen
            output_pdf.save(temp_output, garbage=4, deflate=True, clean=True)
        
        # Erfolgsfall: Temp-Datei ersetzen
        os.replace(temp_output, output_path)
        print(f"INFO: Bearbeitung erfolgreich: '{output_path}'")
        return 0

    except Exception as e:
        # Fehlerbereinigung
        if os.path.exists(temp_output):
            os.remove(temp_output)
        print(f"ERROR: {str(e)}", file=sys.stderr)
        return 1

    finally:
        # Sicherstellen, dass alle Ressourcen geschlossen werden
        if 'output_pdf' in locals():
            output_pdf.close()

def main():
    parser = argparse.ArgumentParser(description='PDF-Bearbeitung: Kontrast/Schärfe anpassen und optional SW-Konvertierung')
    parser.add_argument('input', help='Eingabe-PDF')
    parser.add_argument('output', help='Ausgabe-PDF')
    parser.add_argument('--threshold', type=int, default=None,
                      help='Optional: Schwellenwert für SW-Konvertierung (0-255)')
    parser.add_argument('--absolute-threshold', type=int, default=0,
                      help='Optional: absolute Dunkelschwelle für SW-Flächen (0-255, 0 = deaktiviert)')
    parser.add_argument('--dpi', type=int, default=300,
                      help='Optional: Zielauflösung in DPI (Standard: 300 DPI)')
    parser.add_argument('--contrast', type=float, default=1.0,
                      help='Kontrastfaktor (Standard: 1.0 = keine Änderung)')
    parser.add_argument('--sharpness', type=float, default=1.0,
                      help='Schärfefaktor (Standard: 1.0 = keine Änderung)')
    
    args = parser.parse_args()
    
    if args.threshold is not None and not (0 <= args.threshold <= 255):
        print("ERROR: Schwellenwert muss zwischen 0-255 liegen", file=sys.stderr)
        sys.exit(1)
    if not (0 <= args.absolute_threshold <= 255):
        print("ERROR: Absolute Dunkelschwelle muss zwischen 0-255 liegen", file=sys.stderr)
        sys.exit(1)
    if args.dpi < 72:
        print("ERROR: DPI muss ≥72 sein", file=sys.stderr)
        sys.exit(1)
    
    exit_code = convert_pdf_to_bw(
        args.input, args.output, args.threshold, args.dpi, args.contrast, args.sharpness, args.absolute_threshold
    )
    sys.exit(exit_code)

if __name__ == '__main__':
    main()