defmodule QrLabelSystem.Security.SvgSanitizerTest do
  use ExUnit.Case, async: true

  alias QrLabelSystem.Security.SvgSanitizer

  describe "sanitize/1 - basic validation" do
    test "returns error for nil input" do
      assert {:error, "SVG content is nil"} = SvgSanitizer.sanitize(nil)
    end

    test "returns error for empty string" do
      assert {:error, "SVG content is empty"} = SvgSanitizer.sanitize("")
    end

    test "returns error for non-string input" do
      assert {:error, "SVG content must be a string"} = SvgSanitizer.sanitize(123)
      assert {:error, "SVG content must be a string"} = SvgSanitizer.sanitize([])
      assert {:error, "SVG content must be a string"} = SvgSanitizer.sanitize(%{})
    end

    test "sanitizes valid SVG" do
      svg = ~s[<svg xmlns="http://www.w3.org/2000/svg"><rect width="100" height="100"/></svg>]
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      assert is_binary(result)
    end
  end

  describe "sanitize/1 - script removal" do
    test "removes script elements" do
      svg = "<svg><script>alert('xss')</script><rect/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "script")
      refute String.contains?(result, "alert")
    end

    test "removes script elements with attributes" do
      svg = "<svg><script type=\"text/javascript\">malicious()</script></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "script")
    end

    test "removes self-closing script elements" do
      svg = "<svg><script src=\"evil.js\"/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "script")
    end
  end

  describe "sanitize/1 - dangerous element removal" do
    test "removes foreignObject elements" do
      svg = "<svg><foreignObject><body xmlns=\"http://www.w3.org/1999/xhtml\"><script>alert(1)</script></body></foreignObject></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "foreignObject")
    end

    test "removes iframe elements" do
      svg = "<svg><iframe src=\"http://evil.com\"></iframe></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "iframe")
    end

    test "removes embed elements" do
      svg = "<svg><embed src=\"malicious.swf\"></embed></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "embed")
    end

    test "removes object elements" do
      svg = "<svg><object data=\"evil.swf\"></object></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "object")
    end

    test "removes applet elements" do
      svg = "<svg><applet code=\"Evil.class\"></applet></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "applet")
    end

    test "removes meta elements" do
      svg = "<svg><meta http-equiv=\"refresh\" content=\"0;url=evil.com\"></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "meta")
    end

    test "removes link elements" do
      svg = "<svg><link rel=\"stylesheet\" href=\"evil.css\"></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "link")
    end

    test "removes base elements" do
      svg = "<svg><base href=\"http://evil.com/\"></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "base")
    end

    test "removes style elements" do
      svg = "<svg><style>body { background: url('javascript:alert(1)') }</style></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "style")
    end
  end

  describe "sanitize/1 - event handler removal" do
    test "removes onclick handler" do
      svg = "<svg><rect onclick=\"alert(1)\"/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "onclick")
    end

    test "removes onload handler" do
      svg = "<svg onload=\"alert(1)\"><rect/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "onload")
    end

    test "removes onerror handler" do
      svg = "<svg><image onerror=\"alert(1)\" href=\"x\"/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "onerror")
    end

    test "removes onmouseover handler" do
      svg = "<svg><rect onmouseover=\"alert(1)\"/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "onmouseover")
    end

    test "removes onfocus handler" do
      svg = "<svg><rect onfocus=\"alert(1)\" tabindex=\"1\"/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "onfocus")
    end

    test "removes multiple event handlers" do
      svg = "<svg onclick=\"a()\" onload=\"b()\"><rect onmouseover=\"c()\"/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "onclick")
      refute String.contains?(result, "onload")
      refute String.contains?(result, "onmouseover")
    end
  end

  describe "sanitize/1 - javascript URL removal" do
    test "removes javascript: in href" do
      svg = "<svg><a href=\"javascript:alert(1)\"><rect/></a></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "javascript:")
    end

    test "removes javascript: in xlink:href" do
      svg = "<svg><a xlink:href=\"javascript:alert(1)\"><rect/></a></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "javascript:")
    end

    test "removes javascript: case insensitive" do
      svg = "<svg><a href=\"JAVASCRIPT:alert(1)\"><rect/></a></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(String.downcase(result), "javascript:")
    end
  end

  describe "sanitize/1 - data URL removal" do
    test "removes data:text/html URLs" do
      svg = "<svg><a href=\"data:text/html,<script>alert(1)</script>\"><rect/></a></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "data:text/html")
    end
  end

  describe "sanitize/1 - external reference removal" do
    test "removes external xlink:href" do
      svg = "<svg><use xlink:href=\"http://evil.com/sprite.svg#icon\"/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "http://evil.com")
    end

    test "rejects use elements with href as potentially dangerous" do
      # The sanitizer is conservative and rejects use elements with href
      # even for internal references, as they can be vectors for attacks
      svg = "<svg><defs><rect id=\"myRect\"/></defs><use xlink:href=\"#myRect\"/></svg>"
      assert {:error, msg} = SvgSanitizer.sanitize(svg)
      assert msg =~ "dangerous use elements"
    end

    test "removes protocol-relative URLs" do
      svg = "<svg><use xlink:href=\"//evil.com/sprite.svg#icon\"/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      refute String.contains?(result, "//evil.com")
    end
  end

  describe "sanitize/1 - preserves valid content" do
    test "preserves rect elements" do
      svg = "<svg><rect x=\"10\" y=\"10\" width=\"100\" height=\"100\" fill=\"red\"/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      assert String.contains?(result, "rect")
    end

    test "preserves circle elements" do
      svg = "<svg><circle cx=\"50\" cy=\"50\" r=\"40\" fill=\"blue\"/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      assert String.contains?(result, "circle")
    end

    test "preserves path elements" do
      svg = "<svg><path d=\"M10 10 L90 90\" stroke=\"black\"/></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      assert String.contains?(result, "path")
    end

    test "preserves text elements" do
      svg = "<svg><text x=\"50\" y=\"50\">Hello World</text></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      assert String.contains?(result, "text")
      assert String.contains?(result, "Hello World")
    end

    test "preserves g elements" do
      svg = "<svg><g id=\"group\"><rect/></g></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      assert String.contains?(result, "<g")
    end

    test "preserves defs elements" do
      svg = "<svg><defs><linearGradient id=\"grad\"/></defs></svg>"
      assert {:ok, result} = SvgSanitizer.sanitize(svg)
      assert String.contains?(result, "defs")
    end
  end

  describe "validate/1" do
    test "returns :ok for safe SVG" do
      svg = "<svg><rect width=\"100\" height=\"100\"/></svg>"
      assert :ok = SvgSanitizer.validate(svg)
    end

    test "returns error for script elements" do
      svg = "<svg><script>alert(1)</script></svg>"
      assert {:error, "Contains script elements"} = SvgSanitizer.validate(svg)
    end

    test "returns error for event handlers" do
      svg = "<svg onclick=\"alert(1)\"></svg>"
      assert {:error, "Contains event handlers"} = SvgSanitizer.validate(svg)
    end

    test "returns error for javascript URLs" do
      svg = "<svg><a href=\"javascript:alert(1)\"></a></svg>"
      assert {:error, "Contains javascript: URLs"} = SvgSanitizer.validate(svg)
    end

    test "returns error for data:text/html URLs" do
      svg = "<svg><a href=\"data:text/html,test\"></a></svg>"
      assert {:error, "Contains data:text/html URLs"} = SvgSanitizer.validate(svg)
    end

    test "returns error for foreignObject" do
      svg = "<svg><foreignObject></foreignObject></svg>"
      assert {:error, "Contains foreignObject elements"} = SvgSanitizer.validate(svg)
    end

    test "returns error for non-string input" do
      assert {:error, "SVG content must be a string"} = SvgSanitizer.validate(nil)
      assert {:error, "SVG content must be a string"} = SvgSanitizer.validate(123)
    end
  end
end
