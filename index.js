const ffi = require('ffi-napi');
const ref = require('ref-napi');
const path = require('path');

const PdfOptions = {
  landscape: 'bool',
  print_background: 'bool',
  margin_top: 'double',
  margin_bottom: 'double',
  margin_left: 'double',
  margin_right: 'double',
  page_size: 'string',
  scale: 'double'
};

// ระบุตำแหน่ง library
const libPath = path.join(__dirname, 'zig-out/lib/libhtmlconverter');

const lib = ffi.Library(libPath, {
  'createConverter': ['pointer', []],
  'convertToPdf': ['pointer', ['pointer', 'string', 'int', ref.refType(PdfOptions)]],
  'convertToExcel': ['pointer', ['pointer', 'string', 'int']],
  'destroyConverter': ['void', ['pointer']]
});

class HtmlConverter {
  constructor() {
    this.converter = lib.createConverter();
    if (!this.converter) {
      throw new Error('Failed to create converter');
    }
  }

  convertToPdf(html, options = {}) {
    const defaultOptions = {
      landscape: false,
      print_background: true,
      margin_top: 10,
      margin_bottom: 10,
      margin_left: 10,
      margin_right: 10,
      page_size: 'A4',
      scale: 1.0
    };

    const pdfOptions = { ...defaultOptions, ...options };
    const result = lib.convertToPdf(this.converter, html, html.length, pdfOptions);
    
    if (!result) {
      throw new Error('PDF conversion failed');
    }
    return result;
  }

  convertToExcel(html) {
    const result = lib.convertToExcel(this.converter, html, html.length);
    if (!result) {
      throw new Error('Excel conversion failed');
    }
    return result;
  }

  destroy() {
    if (this.converter) {
      lib.destroyConverter(this.converter);
      this.converter = null;
    }
  }
}

module.exports = HtmlConverter;