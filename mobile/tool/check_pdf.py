"""Run after verify_pdf.dart. Requires pymupdf and pypdf; no app data is used."""
from pathlib import Path
import pymupdf
from pypdf import PdfReader

root = Path(__file__).resolve().parent.parent
pdf_path = root / 'build/qa/searchable-manual.pdf'
document = pymupdf.open(pdf_path)
assert len(document) == 3
expected = ['清洁前请断开电源', '保修说明', '']
reader = PdfReader(pdf_path)
for index, page in enumerate(document):
    text = page.get_text()
    if expected[index]:
        assert expected[index] in text, repr(text)
        assert expected[index] in reader.pages[index].extract_text()
        matches = page.search_for(expected[index])
        assert matches
        assert all(page.rect.contains(rect) for rect in matches)
    else:
        assert not text.strip()
    images = page.get_images()
    assert len(images) == 1
    source = 'landscape.jpg' if index == 1 else 'manual.jpg'
    assert document.extract_image(images[0][0])['image'] == (root / 'test/fixtures' / source).read_bytes()
    page.get_pixmap().save(root / f'build/qa/page-{index+1}.png')
    print(f'Page {index+1}: {len(text)} extracted characters, original JPEG intact')
assert document[0].rect.height > document[0].rect.width
assert document[1].rect.width > document[1].rect.height
print('PASS: two PDF engines, Chinese search inside page bounds, exact scan bytes, orientation, image-only fallback')
