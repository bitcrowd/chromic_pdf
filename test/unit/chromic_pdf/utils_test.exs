# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.UtilsTest do
  use ExUnit.Case, async: true
  import ChromicPDF.Utils

  describe "semver_compare/2" do
    test "compares a semver string with a hardcoded semver list" do
      assert semver_compare("1.2.3", [1, 2, 3]) == :eq
      assert semver_compare("1.2.3", [1, 2]) == :eq
      assert semver_compare("1.1.3", [1, 2]) == :lt
      assert semver_compare("1.3.0", [1, 2]) == :gt
    end
  end
end
