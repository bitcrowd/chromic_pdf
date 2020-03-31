## Unreleased

### Added

- Handle `{:safe, iolist()}` tuples in Processor and Template (for content coming from Phoenix.View).
  Expose `Template.html_concat` as potentially useful helper.

## [0.3.0] - 2020-03-30

### Added

- HTML source and header and footer template accept iolists now
- New `Template` module contains basic CSS skeleton to easily dimension & layout pages (header & footer margins)

## [0.2.0] - 2020-03-06

### Added

- Add `set_cookie` option to `print_to_pdf/2`.

### Changed

- Targets now navigate to `about:blank` after PDF prints.
- Fixed the temporary file yielding way of calling `print_to_pdf/2`.

## [0.1.0] - 2020-03-02

### Added

- First release to hex.pm
