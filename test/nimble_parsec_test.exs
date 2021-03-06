defmodule NimbleParsecTest do
  use ExUnit.Case, async: true

  import NimbleParsec
  doctest NimbleParsec

  describe "ascii_char/2 combinator without newlines" do
    defparsec :only_ascii, ascii_char([?0..?9]) |> ascii_char([])
    defparsec :multi_ascii, ascii_char([?0..?9, ?z..?a])
    defparsec :multi_ascii_with_not, ascii_char([?0..?9, ?z..?a, not: ?c])
    defparsec :multi_ascii_with_multi_not, ascii_char([?0..?9, ?z..?a, not: ?c, not: ?d..?e])
    defparsec :ascii_newline, ascii_char([?0..?9, ?\n]) |> ascii_char([?a..?z, ?\n])

    @error "expected byte in the range ?0..?9, followed by byte"

    test "returns ok/error on composition" do
      assert only_ascii("1a") == {:ok, [?1, ?a], "", 1, 3}
      assert only_ascii("11") == {:ok, [?1, ?1], "", 1, 3}
      assert only_ascii("a1") == {:error, @error, "a1", 1, 1}
    end

    @error "expected byte in the range ?0..?9 or in the range ?z..?a"

    test "returns ok/error on multiple ranges" do
      assert multi_ascii("1a") == {:ok, [?1], "a", 1, 2}
      assert multi_ascii("a1") == {:ok, [?a], "1", 1, 2}
      assert multi_ascii("++") == {:error, @error, "++", 1, 1}
    end

    @error "expected byte in the range ?0..?9 or in the range ?z..?a, and not equal to ?c"

    test "returns ok/error on multiple ranges with not" do
      assert multi_ascii_with_not("1a") == {:ok, [?1], "a", 1, 2}
      assert multi_ascii_with_not("a1") == {:ok, [?a], "1", 1, 2}
      assert multi_ascii_with_not("++") == {:error, @error, "++", 1, 1}
      assert multi_ascii_with_not("cc") == {:error, @error, "cc", 1, 1}
    end

    @error "expected byte in the range ?0..?9 or in the range ?z..?a, and not equal to ?c, and not in the range ?d..?e"

    test "returns ok/error on multiple ranges with multiple not" do
      assert multi_ascii_with_multi_not("1a") == {:ok, [?1], "a", 1, 2}
      assert multi_ascii_with_multi_not("a1") == {:ok, [?a], "1", 1, 2}
      assert multi_ascii_with_multi_not("++") == {:error, @error, "++", 1, 1}
      assert multi_ascii_with_multi_not("cc") == {:error, @error, "cc", 1, 1}
      assert multi_ascii_with_multi_not("de") == {:error, @error, "de", 1, 1}
    end

    test "returns ok/error even with newlines" do
      assert ascii_newline("1a\n") == {:ok, [?1, ?a], "\n", 1, 3}
      assert ascii_newline("1\na") == {:ok, [?1, ?\n], "a", 2, 1}
      assert ascii_newline("\nao") == {:ok, [?\n, ?a], "o", 2, 2}
    end

    test "is bound" do
      assert bound?(ascii_char([?0..?9]))
      assert bound?(ascii_char(not: ?\n))
    end
  end

  describe "utf8_char/2 combinator without newlines" do
    defparsec :only_utf8, utf8_char([?0..?9]) |> utf8_char([])
    defparsec :utf8_newline, utf8_char([]) |> utf8_char([?a..?z, ?\n])

    @error "expected utf8 codepoint in the range ?0..?9, followed by utf8 codepoint"

    test "returns ok/error on composition" do
      assert only_utf8("1a") == {:ok, [?1, ?a], "", 1, 3}
      assert only_utf8("11") == {:ok, [?1, ?1], "", 1, 3}
      assert only_utf8("1é") == {:ok, [?1, ?é], "", 1, 3}
      assert only_utf8("a1") == {:error, @error, "a1", 1, 1}
    end

    test "returns ok/error even with newlines" do
      assert utf8_newline("1a\n") == {:ok, [?1, ?a], "\n", 1, 3}
      assert utf8_newline("1\na") == {:ok, [?1, ?\n], "a", 2, 1}
      assert utf8_newline("éa\n") == {:ok, [?é, ?a], "\n", 1, 3}
      assert utf8_newline("é\na") == {:ok, [?é, ?\n], "a", 2, 1}
      assert utf8_newline("\nao") == {:ok, [?\n, ?a], "o", 2, 2}
    end

    test "is bound" do
      assert bound?(utf8_char([?0..?9]))
      assert bound?(utf8_char(not: ?\n))
    end
  end

  describe "integer/2 combinator with exact length" do
    defparsec :only_integer, integer(2)
    defparsec :prefixed_integer, literal("T") |> integer(2)

    @error "expected byte in the range ?0..?9, followed by byte in the range ?0..?9"

    test "returns ok/error by itself" do
      assert only_integer("12") == {:ok, [12], "", 1, 3}
      assert only_integer("123") == {:ok, [12], "3", 1, 3}
      assert only_integer("1a3") == {:error, @error, "1a3", 1, 1}
    end

    @error "expected literal \"T\", followed by byte in the range ?0..?9, followed by byte in the range ?0..?9"

    test "returns ok/error with previous document" do
      assert prefixed_integer("T12") == {:ok, ["T", 12], "", 1, 4}
      assert prefixed_integer("T123") == {:ok, ["T", 12], "3", 1, 4}
      assert prefixed_integer("T1a3") == {:error, @error, "T1a3", 1, 1}
    end

    test "is bound" do
      assert bound?(integer(2))
      assert bound?(literal("T") |> integer(2))
      assert bound?(literal("T") |> integer(2) |> literal("E"))
    end
  end

  describe "integer/2 combinator with min/max" do
    defparsec :min_integer, integer(min: 3)
    defparsec :max_integer, integer(max: 3)
    defparsec :min_max_integer, integer(min: 1, max: 3)

    @error "expected byte in the range ?0..?9, followed by byte in the range ?0..?9, followed by byte in the range ?0..?9"

    test "returns ok/error with min" do
      assert min_integer("123") == {:ok, [123], "", 1, 4}
      assert min_integer("123o") == {:ok, [123], "o", 1, 4}
      assert min_integer("1234") == {:ok, [1234], "", 1, 5}
      assert min_integer("12") == {:error, @error, "12", 1, 1}
    end

    test "is not bound" do
      assert not_bound?(integer(min: 3))
      assert not_bound?(integer(max: 3))
      assert not_bound?(integer(min: 1, max: 3))
    end
  end

  describe "literal/2 combinator" do
    defparsec :only_literal, literal("TO")
    defparsec :only_literal_with_newline, literal("T\nO")

    test "returns ok/error" do
      assert only_literal("TO") == {:ok, ["TO"], "", 1, 3}
      assert only_literal("TOC") == {:ok, ["TO"], "C", 1, 3}
      assert only_literal("AO") == {:error, "expected literal \"TO\"", "AO", 1, 1}
    end

    test "properly counts newlines" do
      assert only_literal_with_newline("T\nO") == {:ok, ["T\nO"], "", 2, 2}
      assert only_literal_with_newline("T\nOC") == {:ok, ["T\nO"], "C", 2, 2}

      assert only_literal_with_newline("A\nO") ==
               {:error, "expected literal \"T\\nO\"", "A\nO", 1, 1}
    end

    test "is bound" do
      assert bound?(literal("T"))
    end
  end

  describe "ignore/2 combinator at compile time" do
    defparsec :compile_ignore, ignore(literal("TO"))
    defparsec :compile_ignore_with_newline, ignore(literal("T\nO"))

    test "returns ok/error" do
      assert compile_ignore("TO") == {:ok, [], "", 1, 3}
      assert compile_ignore("TOC") == {:ok, [], "C", 1, 3}
      assert compile_ignore("AO") == {:error, "expected literal \"TO\"", "AO", 1, 1}
    end

    test "properly counts newlines" do
      assert compile_ignore_with_newline("T\nO") == {:ok, [], "", 2, 2}
      assert compile_ignore_with_newline("T\nOC") == {:ok, [], "C", 2, 2}

      assert compile_ignore_with_newline("A\nO") ==
               {:error, "expected literal \"T\\nO\"", "A\nO", 1, 1}
    end

    test "is bound" do
      assert bound?(ignore(literal("T")))
    end
  end

  describe "ignore/2 combinator at runtime" do
    defparsec :runtime_ignore,
              ascii_char([?a..?z])
              |> times(min: 1)
              |> ignore()

    test "returns ok/error" do
      assert runtime_ignore("abc") == {:ok, [], "", 1, 4}
      error = "expected byte in the range ?a..?z"
      assert runtime_ignore("1bc") == {:error, error, "1bc", 1, 1}
    end

    test "is not bound" do
      assert not_bound?(ascii_char([?a..?z]) |> times(min: 1) |> ignore())
    end
  end

  describe "replace/3 combinator at compile time" do
    defparsec :compile_replace, replace(literal("TO"), "OTHER")
    defparsec :compile_replace_with_newline, replace(literal("T\nO"), "OTHER")
    defparsec :compile_replace_empty, replace(empty(), "OTHER")

    test "returns ok/error" do
      assert compile_replace("TO") == {:ok, ["OTHER"], "", 1, 3}
      assert compile_replace("TOC") == {:ok, ["OTHER"], "C", 1, 3}
      assert compile_replace("AO") == {:error, "expected literal \"TO\"", "AO", 1, 1}
    end

    test "can replace empty" do
      assert compile_replace_empty("TO") == {:ok, ["OTHER"], "TO", 1, 1}
    end

    test "properly counts newlines" do
      assert compile_replace_with_newline("T\nO") == {:ok, ["OTHER"], "", 2, 2}
      assert compile_replace_with_newline("T\nOC") == {:ok, ["OTHER"], "C", 2, 2}

      assert compile_replace_with_newline("A\nO") ==
               {:error, "expected literal \"T\\nO\"", "A\nO", 1, 1}
    end

    test "is bound" do
      assert bound?(replace(literal("T"), "OTHER"))
      assert bound?(replace(empty(), "OTHER"))
    end
  end

  describe "replace/2 combinator at runtime" do
    defparsec :runtime_replace,
              ascii_char([?a..?z])
              |> times(min: 1)
              |> replace("OTHER")

    test "returns ok/error" do
      assert runtime_replace("abc") == {:ok, ["OTHER"], "", 1, 4}
      error = "expected byte in the range ?a..?z"
      assert runtime_replace("1bc") == {:error, error, "1bc", 1, 1}
    end

    test "is not bound" do
      assert not_bound?(ascii_char([?a..?z]) |> times(min: 1) |> replace("OTHER"))
    end
  end

  describe "label/3 combinator at compile time" do
    defparsec :compile_label, label(literal("TO"), "label")
    defparsec :compile_label_with_newline, label(literal("T\nO"), "label")

    test "returns ok/error" do
      assert compile_label("TO") == {:ok, ["TO"], "", 1, 3}
      assert compile_label("TOC") == {:ok, ["TO"], "C", 1, 3}
      assert compile_label("AO") == {:error, "expected label", "AO", 1, 1}
    end

    test "properly counts newlines" do
      assert compile_label_with_newline("T\nO") == {:ok, ["T\nO"], "", 2, 2}
      assert compile_label_with_newline("T\nOC") == {:ok, ["T\nO"], "C", 2, 2}
      assert compile_label_with_newline("A\nO") == {:error, "expected label", "A\nO", 1, 1}
    end

    test "is bound" do
      assert bound?(label(literal("T"), "label"))
    end
  end

  describe "label/3 combinator at runtime" do
    defparsec :runtime_label,
              label(times(ascii_char([?a..?z]), min: 1), "first label")
              |> label(times(ascii_char([?A..?Z]), min: 1), "second label")
              |> times(ascii_char([?0..?9]), min: 1)
              |> label("third label")

    test "returns ok/error" do
      assert runtime_label("aA0") == {:ok, [?a, ?A, ?0], "", 1, 4}

      error = "expected first label while processing third label"
      assert runtime_label("+A0") == {:error, error, "+A0", 1, 1}

      error = "expected second label while processing third label"
      assert runtime_label("a+0") == {:error, error, "+0", 1, 2}

      error = "expected third label"
      assert runtime_label("aA+") == {:error, error, "+", 1, 3}
    end

    test "is not bound" do
      assert not_bound?(ascii_char([?a..?z]) |> repeat() |> label("label"))
    end
  end

  describe "remote traverse/3 compile combinator" do
    @three_ascii_letters ascii_char([?a..?z])
                         |> ascii_char([?a..?z])
                         |> ascii_char([?a..?z])

    defparsec :remote_traverse,
              literal("T")
              |> integer(2)
              |> traverse(@three_ascii_letters, {__MODULE__, :public_join_and_wrap, ["-"]})
              |> integer(2)

    @error "expected literal \"T\", followed by byte in the range ?0..?9, followed by byte in the range ?0..?9, followed by byte in the range ?a..?z, followed by byte in the range ?a..?z, followed by byte in the range ?a..?z, followed by byte in the range ?0..?9, followed by byte in the range ?0..?9"

    test "returns ok/error" do
      assert remote_traverse("T12abc34") == {:ok, ["T", 12, "99-98-97", 34], "", 1, 9}
      assert remote_traverse("Tabc34") == {:error, @error, "Tabc34", 1, 1}
      assert remote_traverse("T12abcdf") == {:error, @error, "T12abcdf", 1, 1}
      assert remote_traverse("T12ab34") == {:error, @error, "T12ab34", 1, 1}
    end

    test "is bound" do
      assert bound?(traverse(@three_ascii_letters, {__MODULE__, :public_join_and_wrap, ["-"]}))
    end
  end

  describe "remote traverse/3 runtime combinator" do
    @three_ascii_letters times(ascii_char([?a..?z]), min: 3)

    defparsec :remote_runtime_traverse,
              literal("T")
              |> integer(2)
              |> traverse(@three_ascii_letters, {__MODULE__, :public_join_and_wrap, ["-"]})
              |> integer(2)

    test "returns ok/error" do
      assert remote_runtime_traverse("T12abc34") == {:ok, ["T", 12, "99-98-97", 34], "", 1, 9}

      error =
        "expected literal \"T\", followed by byte in the range ?0..?9, followed by byte in the range ?0..?9"

      assert remote_runtime_traverse("Tabc34") == {:error, error, "Tabc34", 1, 1}

      error = "expected byte in the range ?0..?9, followed by byte in the range ?0..?9"
      assert remote_runtime_traverse("T12abcdf") == {:error, error, "", 1, 9}

      error =
        "expected byte in the range ?a..?z, followed by byte in the range ?a..?z, followed by byte in the range ?a..?z"

      assert remote_runtime_traverse("T12ab34") == {:error, error, "ab34", 1, 4}
    end

    test "is bound" do
      assert not_bound?(
               traverse(@three_ascii_letters, {__MODULE__, :public_join_and_wrap, ["-"]})
             )
    end
  end

  describe "local traverse/3 compile combinator" do
    @three_ascii_letters ascii_char([?a..?z])
                         |> ascii_char([?a..?z])
                         |> ascii_char([?a..?z])

    defparsec :local_traverse,
              literal("T")
              |> integer(2)
              |> traverse(@three_ascii_letters, {:private_join_and_wrap, ["-"]})
              |> integer(2)

    @error "expected literal \"T\", followed by byte in the range ?0..?9, followed by byte in the range ?0..?9, followed by byte in the range ?a..?z, followed by byte in the range ?a..?z, followed by byte in the range ?a..?z, followed by byte in the range ?0..?9, followed by byte in the range ?0..?9"

    test "returns ok/error" do
      assert local_traverse("T12abc34") == {:ok, ["T", 12, "99-98-97", 34], "", 1, 9}
      assert local_traverse("Tabc34") == {:error, @error, "Tabc34", 1, 1}
      assert local_traverse("T12abcdf") == {:error, @error, "T12abcdf", 1, 1}
      assert local_traverse("T12ab34") == {:error, @error, "T12ab34", 1, 1}
    end

    test "is bound" do
      assert bound?(traverse(@three_ascii_letters, {:public_join_and_wrap, ["-"]}))
    end
  end

  describe "local traverse/3 runtime combinator" do
    @three_ascii_letters times(ascii_char([?a..?z]), min: 3)

    defparsec :local_runtime_traverse,
              literal("T")
              |> integer(2)
              |> traverse(@three_ascii_letters, {:private_join_and_wrap, ["-"]})
              |> integer(2)

    test "returns ok/error" do
      assert local_runtime_traverse("T12abc34") == {:ok, ["T", 12, "99-98-97", 34], "", 1, 9}

      error =
        "expected literal \"T\", followed by byte in the range ?0..?9, followed by byte in the range ?0..?9"

      assert local_runtime_traverse("Tabc34") == {:error, error, "Tabc34", 1, 1}

      error = "expected byte in the range ?0..?9, followed by byte in the range ?0..?9"
      assert local_runtime_traverse("T12abcdf") == {:error, error, "", 1, 9}

      error =
        "expected byte in the range ?a..?z, followed by byte in the range ?a..?z, followed by byte in the range ?a..?z"

      assert local_runtime_traverse("T12ab34") == {:error, error, "ab34", 1, 4}
    end

    test "is bound" do
      assert not_bound?(traverse(@three_ascii_letters, {:private_join_and_wrap, ["-"]}))
    end
  end

  describe "remote map/3 combinator" do
    defparsec :remote_map,
              ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> map({Integer, :to_string, []})

    defparsec :empty_map, map(empty(), {Integer, :to_string, []})

    test "returns ok/error" do
      assert remote_map("abc") == {:ok, ["97", "98", "99"], "", 1, 4}
      assert remote_map("abcd") == {:ok, ["97", "98", "99"], "d", 1, 4}
      assert {:error, _, "1abcd", 1, 1} = remote_map("1abcd")
    end

    test "can map empty" do
      assert empty_map("abc") == {:ok, [], "abc", 1, 1}
    end
  end

  describe "local map/3 combinator" do
    defparsec :local_map,
              ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> map({:local_to_string, []})

    test "returns ok/error" do
      assert local_map("abc") == {:ok, ["97", "98", "99"], "", 1, 4}
      assert local_map("abcd") == {:ok, ["97", "98", "99"], "d", 1, 4}
      assert {:error, _, "1abcd", 1, 1} = local_map("1abcd")
    end

    defp local_to_string(arg) do
      Integer.to_string(arg)
    end
  end

  describe "remote reduce/3 combinator" do
    defparsec :remote_reduce,
              ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> reduce({Enum, :join, ["-"]})

    defparsec :empty_reduce, reduce(empty(), {Enum, :join, ["-"]})

    test "returns ok/error" do
      assert remote_reduce("abc") == {:ok, ["97-98-99"], "", 1, 4}
      assert remote_reduce("abcd") == {:ok, ["97-98-99"], "d", 1, 4}
      assert {:error, _, "1abcd", 1, 1} = remote_reduce("1abcd")
    end

    test "can reduce empty" do
      assert empty_reduce("abc") == {:ok, [""], "abc", 1, 1}
    end
  end

  describe "local reduce/3 combinator" do
    defparsec :local_reduce,
              ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> ascii_char([?a..?z])
              |> reduce({:local_join, ["-"]})

    test "returns ok/error" do
      assert local_reduce("abc") == {:ok, ["97-98-99"], "", 1, 4}
      assert local_reduce("abcd") == {:ok, ["97-98-99"], "d", 1, 4}
      assert {:error, _, "1abcd", 1, 1} = local_reduce("1abcd")
    end

    defp local_join(list, joiner) do
      Enum.join(list, joiner)
    end
  end

  describe "concat/2 combinator" do
    defparsec :concat_digit_upper_lower_plus,
              concat(
                concat(ascii_char([?0..?9]), ascii_char([?A..?Z])),
                concat(ascii_char([?a..?z]), ascii_char([?+..?+]))
              )

    test "returns ok/error" do
      assert concat_digit_upper_lower_plus("1Az+") == {:ok, [?1, ?A, ?z, ?+], "", 1, 5}
    end
  end

  describe "repeat/2 combinator" do
    defparsec :repeat_digits, repeat(ascii_char([?0..?9]) |> ascii_char([?0..?9]))

    ascii_to_string = map(ascii_char([?0..?9]), {:to_string, []})
    defparsec :repeat_digits_to_string, repeat(ascii_to_string)

    defparsec :repeat_digits_to_same_inner,
              repeat(map(ascii_to_string, {String, :to_integer, []}))

    defparsec :repeat_digits_to_same_outer,
              map(repeat(ascii_to_string), {String, :to_integer, []})

    defparsec :repeat_double_digits_to_string,
              repeat(
                concat(
                  map(ascii_char([?0..?9]), {:to_string, []}),
                  map(ascii_char([?0..?9]), {:to_string, []})
                )
              )

    test "returns ok/error" do
      assert repeat_digits("12") == {:ok, [?1, ?2], "", 1, 3}
      assert repeat_digits("123") == {:ok, [?1, ?2], "3", 1, 3}
      assert repeat_digits("a123") == {:ok, [], "a123", 1, 1}
    end

    test "returns ok/error with map" do
      assert repeat_digits_to_string("123") == {:ok, ["49", "50", "51"], "", 1, 4}
    end

    test "returns ok/error with inner and outer map" do
      assert repeat_digits_to_same_inner("123") == {:ok, [?1, ?2, ?3], "", 1, 4}
      assert repeat_digits_to_same_outer("123") == {:ok, [?1, ?2, ?3], "", 1, 4}
    end

    test "returns ok/error with concat map" do
      assert repeat_double_digits_to_string("12") == {:ok, ["49", "50"], "", 1, 3}
      assert repeat_double_digits_to_string("123") == {:ok, ["49", "50"], "3", 1, 3}
      assert repeat_double_digits_to_string("a123") == {:ok, [], "a123", 1, 1}
    end
  end

  describe "repeat_while/3 combinator" do
    defparsec :repeat_while_digits,
              repeat_while(ascii_char([?0..?9]) |> ascii_char([?0..?9]), {__MODULE__, :not_3, []})

    ascii_to_string = map(ascii_char([?0..?9]), {:to_string, []})
    defparsec :repeat_while_digits_to_string, repeat_while(ascii_to_string, {:not_3, []})

    defparsec :repeat_while_digits_to_same_inner,
              repeat_while(map(ascii_to_string, {String, :to_integer, []}), {:not_3, []})

    defparsec :repeat_while_digits_to_same_outer,
              map(repeat_while(ascii_to_string, {:not_3, []}), {String, :to_integer, []})

    defparsec :repeat_while_double_digits_to_string,
              repeat_while(
                concat(
                  map(ascii_char([?0..?9]), {:to_string, []}),
                  map(ascii_char([?0..?9]), {:to_string, []})
                ),
                {:not_3, []}
              )

    test "returns ok/error" do
      assert repeat_while_digits("1245") == {:ok, [?1, ?2, ?4, ?5], "", 1, 5}
      assert repeat_while_digits("12345") == {:ok, [?1, ?2], "345", 1, 3}
      assert repeat_while_digits("135") == {:ok, [?1, ?3], "5", 1, 3}
      assert repeat_while_digits("312") == {:ok, [], "312", 1, 1}
      assert repeat_while_digits("a123") == {:ok, [], "a123", 1, 1}
    end

    test "returns ok/error with map" do
      assert repeat_while_digits_to_string("123") == {:ok, ["49", "50"], "3", 1, 3}
      assert repeat_while_digits_to_string("321") == {:ok, [], "321", 1, 1}
    end

    test "returns ok/error with inner and outer map" do
      assert repeat_while_digits_to_same_inner("123") == {:ok, [?1, ?2], "3", 1, 3}
      assert repeat_while_digits_to_same_outer("123") == {:ok, [?1, ?2], "3", 1, 3}

      assert repeat_while_digits_to_same_inner("321") == {:ok, [], "321", 1, 1}
      assert repeat_while_digits_to_same_outer("321") == {:ok, [], "321", 1, 1}
    end

    test "returns ok/error with concat map" do
      assert repeat_while_double_digits_to_string("12345") == {:ok, ["49", "50"], "345", 1, 3}
      assert repeat_while_double_digits_to_string("135") == {:ok, ["49", "51"], "5", 1, 3}
      assert repeat_while_double_digits_to_string("312") == {:ok, [], "312", 1, 1}
      assert repeat_while_double_digits_to_string("a123") == {:ok, [], "a123", 1, 1}
    end

    def not_3(<<?3, _::binary>>), do: false
    def not_3(_), do: true
  end

  describe "repeat_until/3 combinator" do
    defparsec :repeat_until_digits,
              repeat_until(ascii_char([?0..?9]) |> ascii_char([?0..?9]), [literal("3")])

    ascii_to_string = map(ascii_char([?0..?9]), {:to_string, []})
    defparsec :repeat_until_digits_to_string, repeat_until(ascii_to_string, [ascii_char([?3])])

    defparsec :repeat_until_digits_to_same_inner,
              repeat_until(map(ascii_to_string, {String, :to_integer, []}), [ascii_char([?3])])

    defparsec :repeat_until_digits_to_same_outer,
              map(repeat_until(ascii_to_string, [ascii_char([?3])]), {String, :to_integer, []})

    defparsec :repeat_until_double_digits_to_string,
              repeat_until(
                concat(
                  map(ascii_char([?0..?9]), {:to_string, []}),
                  map(ascii_char([?0..?9]), {:to_string, []})
                ),
                [ascii_char([?3])]
              )

    test "returns ok/error" do
      assert repeat_until_digits("1245") == {:ok, [?1, ?2, ?4, ?5], "", 1, 5}
      assert repeat_until_digits("12345") == {:ok, [?1, ?2], "345", 1, 3}
      assert repeat_until_digits("135") == {:ok, [?1, ?3], "5", 1, 3}
      assert repeat_until_digits("312") == {:ok, [], "312", 1, 1}
      assert repeat_until_digits("a123") == {:ok, [], "a123", 1, 1}
    end

    test "returns ok/error with map" do
      assert repeat_until_digits_to_string("123") == {:ok, ["49", "50"], "3", 1, 3}
      assert repeat_until_digits_to_string("321") == {:ok, [], "321", 1, 1}
    end

    test "returns ok/error with inner and outer map" do
      assert repeat_until_digits_to_same_inner("123") == {:ok, [?1, ?2], "3", 1, 3}
      assert repeat_until_digits_to_same_outer("123") == {:ok, [?1, ?2], "3", 1, 3}

      assert repeat_until_digits_to_same_inner("321") == {:ok, [], "321", 1, 1}
      assert repeat_until_digits_to_same_outer("321") == {:ok, [], "321", 1, 1}
    end

    test "returns ok/error with concat map" do
      assert repeat_until_double_digits_to_string("12345") == {:ok, ["49", "50"], "345", 1, 3}
      assert repeat_until_double_digits_to_string("135") == {:ok, ["49", "51"], "5", 1, 3}
      assert repeat_until_double_digits_to_string("312") == {:ok, [], "312", 1, 1}
      assert repeat_until_double_digits_to_string("a123") == {:ok, [], "a123", 1, 1}
    end
  end

  describe "times/2 combinator" do
    defparsec :times_digits, times(ascii_char([?0..?9]) |> ascii_char([?0..?9]), max: 4)
    defparsec :times_choice, times(choice([ascii_char([?0..?4]), ascii_char([?5..?9])]), max: 4)

    defparsec :choice_times,
              choice([
                times(ascii_char([?0..?9]), min: 1, max: 4),
                times(ascii_char([?a..?z]), min: 1, max: 4)
              ])

    test "returns ok/error when bound" do
      assert times_digits("12") == {:ok, [?1, ?2], "", 1, 3}
      assert times_digits("123") == {:ok, [?1, ?2], "3", 1, 3}
      assert times_digits("123456789") == {:ok, [?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8], "9", 1, 9}
      assert times_digits("1234567890") == {:ok, [?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8], "90", 1, 9}
      assert times_digits("12o") == {:ok, [?1, ?2], "o", 1, 3}
      assert times_digits("o") == {:ok, [], "o", 1, 1}
    end

    test "returns ok/error with choice" do
      assert times_choice("12") == {:ok, [?1, ?2], "", 1, 3}
      assert times_choice("123") == {:ok, [?1, ?2, ?3], "", 1, 4}
      assert times_choice("12345") == {:ok, [?1, ?2, ?3, ?4], "5", 1, 5}
      assert times_choice("12o") == {:ok, [?1, ?2], "o", 1, 3}
      assert times_choice("o") == {:ok, [], "o", 1, 1}
    end

    @error "expected byte in the range ?0..?9, followed by byte in the range ?0..?9 or byte in the range ?a..?z, followed by byte in the range ?a..?z"

    test "returns ok/error with outer choice" do
      assert choice_times("12") == {:ok, [?1, ?2], "", 1, 3}
      assert choice_times("12a") == {:ok, [?1, ?2], "a", 1, 3}
      assert choice_times("12345") == {:ok, [?1, ?2, ?3, ?4], "5", 1, 5}
      assert choice_times("ab") == {:ok, [?a, ?b], "", 1, 3}
      assert choice_times("ab1") == {:ok, [?a, ?b], "1", 1, 3}
      assert choice_times("abcde") == {:ok, [?a, ?b, ?c, ?d], "e", 1, 5}
      assert choice_times("+") == {:error, @error, "+", 1, 1}
    end
  end

  describe "choice/2 combinator" do
    defparsec :simple_choice,
              choice([ascii_char([?a..?z]), ascii_char([?A..?Z]), ascii_char([?0..?9])])

    defparsec :choice_inner_repeat,
              choice([repeat(ascii_char([?a..?z])), repeat(ascii_char([?A..?Z]))])

    defparsec :choice_outer_repeat, repeat(choice([ascii_char([?a..?z]), ascii_char([?A..?Z])]))

    defparsec :choice_repeat_and_inner_map,
              repeat(
                choice([
                  map(ascii_char([?a..?z]), {:to_string, []}),
                  map(ascii_char([?A..?Z]), {:to_string, []})
                ])
              )

    defparsec :choice_repeat_and_maps,
              map(
                repeat(
                  choice([
                    map(ascii_char([?a..?z]), {:to_string, []}),
                    map(ascii_char([?A..?Z]), {:to_string, []})
                  ])
                ),
                {String, :to_integer, []}
              )

    defparsec :choice_with_empty,
              choice([
                ascii_char([?a..?z]),
                empty()
              ])

    @error "expected byte in the range ?a..?z or byte in the range ?A..?Z or byte in the range ?0..?9"

    test "returns ok/error" do
      assert simple_choice("a=") == {:ok, [?a], "=", 1, 2}
      assert simple_choice("A=") == {:ok, [?A], "=", 1, 2}
      assert simple_choice("0=") == {:ok, [?0], "=", 1, 2}
      assert simple_choice("+=") == {:error, @error, "+=", 1, 1}
    end

    test "returns ok/error with repeat inside" do
      assert choice_inner_repeat("az") == {:ok, [?a, ?z], "", 1, 3}
      assert choice_inner_repeat("AZ") == {:ok, [], "AZ", 1, 1}
    end

    test "returns ok/error with repeat outside" do
      assert choice_outer_repeat("az") == {:ok, [?a, ?z], "", 1, 3}
      assert choice_outer_repeat("AZ") == {:ok, [?A, ?Z], "", 1, 3}
      assert choice_outer_repeat("aAzZ") == {:ok, [?a, ?A, ?z, ?Z], "", 1, 5}
    end

    test "returns ok/error with repeat and inner map" do
      assert choice_repeat_and_inner_map("az") == {:ok, ["97", "122"], "", 1, 3}
      assert choice_repeat_and_inner_map("AZ") == {:ok, ["65", "90"], "", 1, 3}
      assert choice_repeat_and_inner_map("aAzZ") == {:ok, ["97", "65", "122", "90"], "", 1, 5}
    end

    test "returns ok/error with repeat and maps" do
      assert choice_repeat_and_maps("az") == {:ok, [?a, ?z], "", 1, 3}
      assert choice_repeat_and_maps("AZ") == {:ok, [?A, ?Z], "", 1, 3}
      assert choice_repeat_and_maps("aAzZ") == {:ok, [?a, ?A, ?z, ?Z], "", 1, 5}
    end

    test "returns ok/error on empty" do
      assert choice_with_empty("az") == {:ok, [?a], "z", 1, 2}
      assert choice_with_empty("AZ") == {:ok, [], "AZ", 1, 1}
    end
  end

  describe "optional/2 combinator" do
    defparsec :optional_ascii, optional(ascii_char([?a..?z]))

    test "returns ok/error on empty" do
      assert optional_ascii("az") == {:ok, [?a], "z", 1, 2}
      assert optional_ascii("AZ") == {:ok, [], "AZ", 1, 1}
    end
  end

  describe "parsec/2 combinator" do
    defparsecp :parsec_inner,
               choice([
                 map(ascii_char([?a..?z]), {:to_string, []}),
                 map(ascii_char([?A..?Z]), {:to_string, []})
               ])

    defparsec :parsec_literal, literal("T") |> parsec(:parsec_inner) |> literal("O")
    defparsec :parsec_repeat, repeat(parsec(:parsec_inner))
    defparsec :parsec_map, map(parsec(:parsec_inner), {String, :to_integer, []})
    defparsec :parsec_choice, choice([parsec(:parsec_inner), literal("+")])

    test "returns ok/error with literal" do
      assert parsec_literal("TaO") == {:ok, ["T", "97", "O"], "", 1, 4}

      error = "expected literal \"T\""
      assert parsec_literal("ZaO") == {:error, error, "ZaO", 1, 1}

      error = "expected byte in the range ?a..?z or byte in the range ?A..?Z"
      assert parsec_literal("T1O") == {:error, error, "1O", 1, 2}

      error = "expected literal \"O\""
      assert parsec_literal("TaA") == {:error, error, "A", 1, 3}
    end

    test "returns ok/error with choice" do
      assert parsec_choice("+O") == {:ok, ["+"], "O", 1, 2}
      assert parsec_choice("O+") == {:ok, ["79"], "+", 1, 2}
      assert parsec_choice("==") == {:error, "expected parsec_inner or literal \"+\"", "==", 1, 1}
    end

    test "returns ok/error with repeat" do
      assert parsec_repeat("az") == {:ok, ["97", "122"], "", 1, 3}
      assert parsec_repeat("AZ") == {:ok, ["65", "90"], "", 1, 3}
      assert parsec_repeat("aAzZ") == {:ok, ["97", "65", "122", "90"], "", 1, 5}
      assert parsec_repeat("1aAzZ") == {:ok, [], "1aAzZ", 1, 1}
    end

    @error "expected byte in the range ?a..?z or byte in the range ?A..?Z"

    test "returns ok/error with map" do
      assert parsec_map("az") == {:ok, [?a], "z", 1, 2}
      assert parsec_map("AZ") == {:ok, [?A], "Z", 1, 2}
      assert parsec_map("1aAzZ") == {:error, @error, "1aAzZ", 1, 1}
    end
  end

  describe "custom datetime/2 combinator" do
    date =
      integer(4)
      |> ignore(literal("-"))
      |> integer(2)
      |> ignore(literal("-"))
      |> integer(2)

    time =
      integer(2)
      |> ignore(literal(":"))
      |> integer(2)
      |> ignore(literal(":"))
      |> integer(2)

    defparsec :datetime, date |> ignore(literal("T")) |> concat(time)

    test "returns ok/error by itself" do
      assert datetime("2010-04-17T14:12:34") == {:ok, [2010, 4, 17, 14, 12, 34], "", 1, 20}
    end
  end

  defp bound?(document) do
    {defs, _} = NimbleParsec.Compiler.compile(:not_used, document, [])

    assert length(defs) == 3,
           "Expected #{inspect(document)} to contain 3 clauses, got #{length(defs)}"
  end

  defp not_bound?(document) do
    {defs, _} = NimbleParsec.Compiler.compile(:not_used, document, [])

    assert length(defs) != 3, "Expected #{inspect(document)} to contain more than 3 clauses"
  end

  def public_join_and_wrap(args, joiner) do
    args |> Enum.join(joiner) |> List.wrap()
  end

  defp private_join_and_wrap(args, joiner) do
    args |> Enum.join(joiner) |> List.wrap()
  end
end
