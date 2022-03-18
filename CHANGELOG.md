## [1.2.0] - 2022-03-17

### Added

- Improved docs on header/footer templates saying that external URLs don't work.
- Added a logger call when we receive the `Inspector.targetCrashed` message, so users can tell that their Chrome target has died for some reason.
- Add more paper sizes to `ChromicPDF.Template`. (@williamthome)
- Add `:landscape` option to `ChromicPDF.Template`. (@williamthome)
- Add `:init_timeout` option to `ChromicPDF.Browser.SessionPool`. (@dvic)

## [1.1.2] - 2021-10-27

### Fixed

- Documentation updates (@kianmeng)

## [1.1.1] - 2021-09-24

### Added

- Relaxed telemetry dependency to avoid blocking dependency update (@leandrocp)
- Add chromium path on macOS when installed via homebrew (@shamanime)

## [1.1.0] - 2021-04-16

### Changed

- Improved error message when Chrome dies at startup.
- Improved docs on the `no_sandbox` option.

### Added

- Added `chrome_executable` option to allow specifying path to chrome executable.

## [1.0.0] - 2021-03-23

### Added

- Added `evaluate` option to run client-side scripts before printing.
- Added a few options (`evaluate`, `set_cookie`, `wait_for`) to `capture_screenshot/2`.

### Changed

- Reimplemented `wait_for` option based on a JS script and the `evaluate` option to overcome
  race condition issues of original solution. Behaviour remains the same.

## [0.7.2] - 2021-02-26

### Fixed

- Enforced telemetry version 0.4.2 (fixes #108)

## [0.7.1] - 2021-02-08

### Fixed

- To determine the session pool / ghostscript pool size, if not specified in the options, we now
  fetch the number of schedulers at runtime, not compile time. Makes more sense. We also set a
  minimum of 1 in case there is only 1 scheduler online.

## [0.7.0] - 2021-01-25

### Added

- Added option `wait_for` to wait for DOM element attribute to be set dynamically. (@jarimatti)
- New global `timeout` option for session pool allows to configure timeout of print processes.
- New global `ignore_certificate_errors` option allows to bypass SSL certificate verification.
- New global `chrome_args` option allows to pass custom flags to chrome command.

## [0.6.2] - 2020-12-28

### Fixed

- When sending HTML to Chrome with `{:html, <content>}`, wait for the `Page.loadEventFired`
  notification to allow external resources (images, scripts, ...) to be fetched. (#80)

## [0.6.1] - 2020-11-17

### Fixed

- Reverted to file descriptor redirection to mitigate weird Port behaviour (#76).

## [0.6.0] - 2020-11-16

### Changed

- Elixir version housekeeping. Fixed a warning on Elixir 1.11 by adding `:eex` to
  `:extra_applications`. ChromicPDF now **requires Elixir >= 1.10** for its use of
  `Application.compile_env/3`.
- Dropped `poolboy` in favour of `nimble_pool`. This renders the `max_overflow` poolboy option
  without effect.
- Made "online mode" the default. Chrome will resolve all URL references unless the global
  option `offline: false` is set.

### Added

- Added telemetry events for the PDF generation & PDF/A conversion.
- "On Demand" mode allows to start & stop Chrome as needed, much like puppeteer does. This helps
  in development to prevent leaving behind zombie processes when the BEAM is aborted with Ctrl+C.
- New global option `discard_stderr` allows to enable Chrome's stderr logging which is by default
  piped to `/dev/null`.

### Fixed

- Graceful shutdown is now actually graceful in that it waits for Chrome to clean up the
  debugging sessions and close the pipe on its end.

## [0.5.2] - 2020-07-17

### Fixed

- Moved static files required for PDF/A generation to /priv so they are embedded into releases.
- Moved logo files *out of* /priv so they are not included in releases.

## [0.5.1] - 2020-07-10

### Fixed

- Fixed typespecs for `Template.source_and_options/1`. `[content_option]` weren't allowed as
  call to `styles/1` narrowed type to `[style_option]`.
- Added missing keys to `style_option`.

## [0.5.0] - 2020-07-10

### Changed

- Removed the `:width` and `:height` options from `Template.styles/1` and
  `Template.source_and_options/1` as it turns out that Chrome does not pay attention to `@page`
  dimensions and instead still sets the size of the produced PDF to US letter. Since it does not
  seem possible to the PDF size in Chrome headless besides using the `paperWidth` and
  `paperHeight` options, moved to a `:size` option instead that accepts names like `:a4`,
  `:us_letter`, and tuples of `{<width>, <height>}` in inches. These are then passed to
  `paperWidth` and `paperHeight`.
- Ditched the `preferCssPageSize` option from `Template.source_and_options/1` as it did not seem
  to have any effect. See above.

### Added

- Added `zoom: 0.75` to both `#header` and `#footer` in the template as this seems to be exactly
  what is needed to reverse the viewport scaling that Chrome uses on them by default. With this,
  headers & footers and the content can use the same CSS styles.
- Included `-webkit-print-color-adjust: exact` rule to template so `background-color` rules are
  enabled by default.

### Fixed

- Make `print_to_pdfa/2` actually accept `source_and_options()` map from `Template`.

## [0.4.0] - 2020-07-09

### Added

- Allow `{:url, <path>}` input tuples where path is only a path, and not a `file://` URL.

### Changed

- When passing a function to the `:output` parameter, the function result will now be returned as
  part of the `print_to_pdf` & friends result as `{:ok, <callback_result>}` instead of `:ok`.

## [0.3.1] - 2020-04-09

### Added

- Handle `{:safe, iolist()}` tuples in API and Template (for content coming from Phoenix.View).
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
