# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.ChromeRunnerTest do
  use ExUnit.Case, async: true
  alias ChromicPDF.ChromeRunner

  describe ":chrome_args option" do
    test "additional arguments passed as binary" do
      command = ChromeRunner.shell_command(chrome_args: "--some-extra-arg")
      assert command =~ "--some-extra-arg"
    end

    test "removal of default arguments via extended :chrome_args" do
      assert ChromeRunner.shell_command([]) =~ "--no-first-run"

      command =
        ChromeRunner.shell_command(
          chrome_args: [remove: "--no-first-run", append: "--some-extra-arg"]
        )

      assert command =~ "--some-extra-arg"
      refute command =~ "--no-first-run"
    end
  end
end
