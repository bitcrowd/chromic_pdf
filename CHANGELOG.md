## [0.4.0] - 2020-07-09

### Added

- Allow `{:url, <path>}` input tuples where path is only a path, and not a `file://` URL.

### Changed

- When passing a function to the `:output` parameter, the function result will now be returned as
  part of the `print_to_pdf` & friends result as `{:ok, <callback_result>}` instead of `:ok`.

## [0.3.1] - 2020-04-09

### Added

- Handle `{:safe, iolist()}` tuples in Processor and Template (for content coming from Phoenix.View).
  Expose `Template.html_concat` as potentially useful helper.
- Reset navigation history after each print job to avoid leaking information.
- Create new empty browser context for each target (similar to incognito tab).
- Restart browser target after a maximum number of PDFs have been printed to avoid memory bloat.

### Changed

- Set user agent to custom string.
- Default number of sessions in pool to half the number of available cores.

## [0.3.0] - 2020-03-30

### Added

- HTML source and header and footer template accept iolists now
- New `Template` module contains basic CSS skeleton to easily dimension & layout pages (header & footer margins)

## [0.2.0] - 2020-03-06

### Added

- Add `set_cookie` option to `print_to_pdf/2`.
- Targets now navigate to `about:blank` after PDF prints.
- Fixed the temporary file yielding way of calling `print_to_pdf/2`.

## [0.1.0] - 2020-03-02

### Added

- First release to hex.pm
