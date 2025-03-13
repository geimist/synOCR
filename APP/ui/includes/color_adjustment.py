#!/usr/bin/env python3

#############################################################################################
#   description:    Dieses Skript passt Kontrast/Schärfe von PDFs an und ermöglicht optional #
#                   eine 1-Bit-Schwarzweiß-Konvertierung.                                   #
#   path:           /usr/syno/synoman/webman/3rdparty/synOCR/includes/color_adjustment.py   #
#   © 2025 by geimist                                                                       #
#############################################################################################

import fitz
from PIL import Image, ImageEnhance
import io
import argparse
import sys
import os
import numpy as np
import tempfile

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

def convert_pdf_to_bw(input_path, output_path, threshold=None, dpi=300, contrast=1.0, sharpness=1.0):
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
                    pix = page.get_pixmap(matrix=matrix, alpha=False)
                else:
                    pix = page.get_pixmap(alpha=False)
                
                img_data = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
                img_enhanced = enhance_image(img_data, contrast, sharpness)
                
                if threshold is not None:
                    img_gray = img_enhanced.convert('L')
                    img_array = np.array(img_gray)
                    kernel_size = 25
                    local_mean = np.zeros_like(img_array, dtype=float)
                    
                    # Blockweise Mittelwertberechnung
                    for i in range(0, img_array.shape[0], kernel_size):
                        for j in range(0, img_array.shape[1], kernel_size):
                            block = img_array[i:i+kernel_size, j:j+kernel_size]
                            local_mean[i:i+kernel_size, j:j+kernel_size] = np.mean(block)
                    
                    img_bw = Image.fromarray(np.where(img_array > local_mean - threshold, 255, 0).astype(np.uint8))
                    img_bw = img_bw.convert('1')
                    final_img = img_bw
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
    if args.dpi < 72:
        print("ERROR: DPI muss ≥72 sein", file=sys.stderr)
        sys.exit(1)
    
    exit_code = convert_pdf_to_bw(
        args.input, args.output, args.threshold, args.dpi, args.contrast, args.sharpness
    )
    sys.exit(exit_code)

if __name__ == '__main__':
    main()