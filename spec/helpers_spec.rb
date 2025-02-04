require "spec_helper"

describe SDoc::Helpers do
  before :each do
    @helpers = Class.new do
      include ERB::Util
      include SDoc::Helpers

      attr_accessor :options
    end.new

    @helpers.options = RDoc::Options.new
  end

  describe "#github_url" do
    before :each do
      @helpers.options.github = true
    end

    it "returns the URL for a given path in the project's GitHub repository at the current SHA1" do
      @helpers.git_bin_path = "path/to/git"
      @helpers.git_origin_url = "git@github.com:user/repo.git"
      @helpers.git_head_sha1 = "1337c0d3"

      _(@helpers.github_url("foo/bar/qux.rb")).
        must_equal "https://github.com/user/repo/blob/1337c0d3/foo/bar/qux.rb"
    end

    it "detects the GitHub repository name and current SHA1 (smoke test)" do
      _(@helpers.github_url("foo/bar/qux.rb")).
        must_match %r"\Ahttps://github.com/[^/]+/sdoc/blob/[0-9a-f]{40}/foo/bar/qux\.rb\z"
    end

    it "supports HTTPS remote URL" do
      @helpers.git_origin_url = "https://github.com/user/repo.git"

      _(@helpers.github_url("foo/bar/qux.rb")).
        must_match %r"\Ahttps://github.com/user/repo/blob/[0-9a-f]{40}/foo/bar/qux\.rb\z"
    end

    it "supports HTTPS remote URL without .git extension" do
      @helpers.git_origin_url = "https://github.com/user/repo"

      _(@helpers.github_url("foo/bar/qux.rb")).
        must_match %r"\Ahttps://github.com/user/repo/blob/[0-9a-f]{40}/foo/bar/qux\.rb\z"
    end

    it "returns nil when options.github is false" do
      @helpers.options.github = false

      _(@helpers.github_url("foo/bar/qux.rb")).must_be_nil
    end

    it "returns nil when git is not installed" do
      @helpers.git_bin_path = ""

      _(@helpers.github_url("foo/bar/qux.rb")).must_be_nil
    end

    it "returns nil when 'origin' remote is not present" do
      @helpers.git_origin_url = ""

      _(@helpers.github_url("foo/bar/qux.rb")).must_be_nil
    end

    it "returns nil when 'origin' remote is not recognized" do
      @helpers.git_origin_url = "git@gitlab.com:user/repo.git"

      _(@helpers.github_url("foo/bar/qux.rb")).must_be_nil
    end

    it "supports :line option" do
      _(@helpers.github_url("foo/bar/qux.rb", line: 123)).
        must_match %r"\Ahttps://github.com/.+/foo/bar/qux\.rb#L123\z"
    end
  end

  describe "#link_to" do
    it "returns a link tag" do
      _(@helpers.link_to("Foo::Bar::Qux", "foo/bar/qux.html")).
        must_equal %(<a href="foo/bar/qux.html">Foo::Bar::Qux</a>)
    end

    it "supports HTML attributes" do
      _(@helpers.link_to("foo", "bar", class: "qux", "data-hoge": "fuga")).
        must_equal %(<a href="bar" class="qux" data-hoge="fuga">foo</a>)
    end

    it "escapes the link text and attributes" do
      _(@helpers.link_to("Bar < Foo", "qux", title: "Foo > Bar")).
        must_equal %(<a href="qux" title="Foo &gt; Bar">Bar &lt; Foo</a>)
    end

    it "returns the escaped text when URL argument is nil" do
      _(@helpers.link_to("Bar < Foo", nil, title: "Foo > Bar")).
        must_equal %(Bar &lt; Foo)
    end

    it "returns an appropriate link when URL argument is an RDoc::CodeObject that responds to #path" do
      top_level = rdoc_top_level_for <<~RUBY
        module Foo; class Bar; def qux; end; end; end
      RUBY

      _(@helpers.link_to("perma", top_level.find_module_named("Foo"))).
        must_equal %(<a href="/classes/Foo.html">perma</a>)

      _(@helpers.link_to("perma", top_level.find_module_named("Foo::Bar"))).
        must_equal %(<a href="/classes/Foo/Bar.html">perma</a>)

      _(@helpers.link_to("perma", top_level.find_module_named("Foo::Bar").find_method("qux", false))).
        must_equal %(<a href="/classes/Foo/Bar.html#method-i-qux">perma</a>)
    end
  end

  describe "#link_to_external" do
    it "sets class='external-link' and target='_blank' by default" do
      _(@helpers.link_to_external("foo", "bar")).
        must_equal %(<a href="bar" target="_blank" class="external-link">foo</a>)
    end

    it "supports additional classes" do
      _(@helpers.link_to_external("foo", "bar", class: "qux")).
        must_equal %(<a href="bar" target="_blank" class="qux external-link">foo</a>)
    end

    it "supports overriding target" do
      _(@helpers.link_to_external("foo", "bar", target: "_self")).
        must_equal %(<a href="bar" target="_self" class="external-link">foo</a>)
    end

    it "supports additional attributes" do
      _(@helpers.link_to_external("foo", "bar", "data-hoge": "fuga")).
        must_equal %(<a href="bar" target="_blank" class="external-link" data-hoge="fuga">foo</a>)
    end
  end

  describe "#base_tag_for_context" do
    it "returns an idempotent <base> tag for nil context" do
      _(@helpers.base_tag_for_context(nil)).
        must_equal %(<base href="./" data-current-path="">)
    end

    it "returns a <base> tag with an appropriate path for the given RDoc::Context" do
      top_level = rdoc_top_level_for <<~RUBY
        module Foo; module Bar; module Qux; end; end; end
      RUBY

      _(@helpers.base_tag_for_context(top_level.find_module_named("Foo"))).
        must_equal %(<base href="./../" data-current-path="classes/Foo.html">)

      _(@helpers.base_tag_for_context(top_level.find_module_named("Foo::Bar"))).
        must_equal %(<base href="./../../" data-current-path="classes/Foo/Bar.html">)

      _(@helpers.base_tag_for_context(top_level.find_module_named("Foo::Bar::Qux"))).
        must_equal %(<base href="./../../../" data-current-path="classes/Foo/Bar/Qux.html">)
    end
  end

  describe "#canonical_url" do
    it "returns a URL based on ENV['HORO_CANONICAL_URL'] for an RDoc::Context" do
      context = rdoc_top_level_for(<<~RUBY).find_module_named("Foo::Bar::Qux")
        module Foo; module Bar; module Qux; end; end; end
      RUBY

      with_env("HORO_CANONICAL_URL" => "https://canonical") do
        _(@helpers.canonical_url(context)).must_equal "https://canonical/classes/Foo/Bar/Qux.html"
      end
    end

    it "returns a URL based on ENV['HORO_CANONICAL_URL'] for a path" do
      with_env("HORO_CANONICAL_URL" => "https://canonical") do
        _(@helpers.canonical_url("/path/to/foo")).must_equal "https://canonical/path/to/foo"
        _(@helpers.canonical_url("path/to/foo")).must_equal "https://canonical/path/to/foo"
      end
    end

    it "returns a URL based on ENV['HORO_CANONICAL_URL'] for nil" do
      with_env("HORO_CANONICAL_URL" => "https://canonical") do
        _(@helpers.canonical_url(nil)).must_equal "https://canonical/"
      end
    end

    it "returns nil when ENV['HORO_CANONICAL_URL'] is not set" do
      with_env("HORO_CANONICAL_URL" => nil) do
        _(@helpers.canonical_url(nil)).must_be_nil
      end
    end
  end

  describe "#project_name" do
    it "returns escaped name from ENV['HORO_PROJECT_NAME']" do
      with_env("HORO_PROJECT_NAME" => "Ruby & Rails") do
        _(@helpers.project_name).must_equal "Ruby &amp; Rails"
      end
    end

    it "returns nil when ENV['HORO_PROJECT_NAME'] is not set" do
      with_env("HORO_PROJECT_NAME" => nil) do
        _(@helpers.project_name).must_be_nil
      end
    end
  end

  describe "#project_version" do
    it "returns escaped version from ENV['HORO_PROJECT_VERSION']" do
      with_env("HORO_PROJECT_VERSION" => "~> 1.0.0") do
        _(@helpers.project_version).must_equal "~&gt; 1.0.0"
      end
    end

    it "returns nil when ENV['HORO_PROJECT_VERSION'] is not set" do
      with_env("HORO_PROJECT_VERSION" => nil) do
        _(@helpers.project_version).must_be_nil
      end
    end
  end

  describe "#badge_version" do
    it "returns escaped version from ENV['HORO_BADGE_VERSION']" do
      with_env("HORO_BADGE_VERSION" => "~> 1.0.0") do
        _(@helpers.badge_version).must_equal "~&gt; 1.0.0"
      end
    end

    it "returns nil when ENV['HORO_BADGE_VERSION'] is not set" do
      with_env("HORO_BADGE_VERSION" => nil) do
        _(@helpers.badge_version).must_be_nil
      end
    end
  end

  describe "#page_title" do
    it "includes options.title" do
      @helpers.options.title = "My Docs"

      _(@helpers.page_title).must_equal "My Docs"
      _(@helpers.page_title("Foo")).must_equal "Foo - My Docs"
    end

    it "escapes the title" do
      @helpers.options.title = "Docs & Stuff"

      _(@helpers.page_title("Foo<Bar>")).must_equal "Foo&lt;Bar&gt; - Docs &amp; Stuff"
    end
  end

  describe "#og_title" do
    it "includes ENV['HORO_PROJECT_NAME'] and ENV['HORO_BADGE_VERSION']" do
      with_env("HORO_PROJECT_NAME" => "My Gem", "HORO_BADGE_VERSION" => "v2.0") do
        _(@helpers.og_title("Foo")).must_equal "Foo (My Gem v2.0)"
      end

      with_env("HORO_PROJECT_NAME" => "My Gem", "HORO_BADGE_VERSION" => nil) do
        _(@helpers.og_title("Foo")).must_equal "Foo (My Gem)"
      end

      with_env("HORO_PROJECT_NAME" => nil, "HORO_BADGE_VERSION" => "v2.0") do
        _(@helpers.og_title("Foo")).must_equal "Foo (v2.0)"
      end

      with_env("HORO_PROJECT_NAME" => nil, "HORO_BADGE_VERSION" => nil) do
        _(@helpers.og_title("Foo")).must_equal "Foo"
      end
    end

    it "escapes the title" do
      with_env("HORO_PROJECT_NAME" => "Ruby & Rails", "HORO_BADGE_VERSION" => "~> 1.0.0") do
        _(@helpers.og_title("Foo<Bar>")).must_equal "Foo&lt;Bar&gt; (Ruby &amp; Rails ~&gt; 1.0.0)"
      end
    end
  end

  describe "#og_modified_time" do
    it "returns the commit time of the most recent commit in HEAD" do
      @helpers.git_bin_path = "path/to/git"
      @helpers.git_head_timestamp = "1999-12-31T12:34:56Z"

      _(@helpers.og_modified_time).must_equal "1999-12-31T12:34:56Z"
    end

    it "returns the commit time of the most recent commit in HEAD (smoke test)" do
      _(@helpers.og_modified_time).
        must_match %r"\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[-+]\d{2}:\d{2}\z"
    end

    it "returns nil when git is not installed" do
      @helpers.git_bin_path = ""

      _(@helpers.og_modified_time).must_be_nil
    end
  end

  describe "#page_description" do
    it "extracts the description from the leading paragraph" do
      _(@helpers.page_description(<<~HTML)).must_equal "leading"
        <p>leading</p>
        <p>other</p>
      HTML

      _(@helpers.page_description(<<~HTML)).must_equal "paragraph"
        <h1>headline</h1>
        <p>paragraph</p>
      HTML
    end

    it "returns nil when there is no leading paragraph" do
      _(@helpers.page_description(<<~HTML)).must_be_nil
        <pre><code>code</code></pre>
        <p>other</p>
      HTML

      _(@helpers.page_description("")).must_be_nil
      _(@helpers.page_description(nil)).must_be_nil
    end

    it "strips HTML tags" do
      _(@helpers.page_description(<<~HTML)).must_equal "emphatic text"
        <p><em>emphatic</em> text</p>
      HTML
    end

    it "escapes the text" do
      _(@helpers.page_description(<<~HTML)).must_equal "x &lt; y"
        <p>x &lt; y</p>
      HTML
    end

    it "truncates at word boundaries" do
      leading_html = "<p>12345 78. 12, 5 - 9.</p>"

      {
         8..10 => "12345...",
        11..14 => "12345 78...",
        15..17 => "12345 78. 12...",
        18..19 => "12345 78. 12, 5...",
        20..25 => "12345 78. 12, 5 - 9.",
      }.each do |range, expected|
        range.each do |max_length|
          _(@helpers.page_description(leading_html, max_length: max_length)).must_equal expected
        end
      end
    end

    it "truncates to 160 characters by default" do
      _(@helpers.page_description("<p>#{"x" * 150}123 567 9.</p>")).
        must_equal "#{"x" * 150}123 567 9."

      _(@helpers.page_description("<p>#{"x" * 150}123 567 xxx.</p>")).
        must_equal "#{"x" * 150}123 567..."
    end
  end

  describe "#group_by_first_letter" do
    it "groups RDoc objects by the first letter of their #name" do
      context = rdoc_top_level_for(<<~RUBY).find_module_named("Foo")
        module Foo
          def bar; end
          def _bar; end
          def baa; end

          def qux; end
          def _qux; end
          def Qux; end
        end
      RUBY

      expected = {
        "#" => [context.find_method("_bar", false), context.find_method("_qux", false)],
        "B" => [context.find_method("baa", false), context.find_method("bar", false)],
        "Q" => [context.find_method("Qux", false), context.find_method("qux", false)],
      }

      _(@helpers.group_by_first_letter(context.method_list)).must_equal expected
    end
  end

  describe "#method_source_code_and_url" do
    before :each do
      @helpers.options.github = true
    end

    it "returns source code and GitHub URL for a given RDoc::AnyMethod" do
      method = rdoc_top_level_for(<<~RUBY).find_module_named("Foo").find_method("bar", false)
        module Foo # line 1
          def bar # line 2
            # line 3
          end
        end
      RUBY

      source_code, source_url = @helpers.method_source_code_and_url(method)

      _(source_code).must_match %r"# File .+\.rb, line 2\b"
      _(source_code).must_include "line 3"
      _(source_url).must_match %r"\Ahttps://github.com/.+\.rb#L2\z"
    end

    it "returns nil source code when given method is an RDoc::GhostMethod" do
      method = rdoc_top_level_for(<<~RUBY).find_module_named("Foo").find_method("bar", false)
        module Foo # line 1
          ##
          # :method: bar
        end
      RUBY

      source_code, source_url = @helpers.method_source_code_and_url(method)

      _(source_code).must_be_nil
      _(source_url).must_match %r"\Ahttps://github.com/.+\.rb#L3\z"
    end

    it "returns nil source code when given method is an alias" do
      method = rdoc_top_level_for(<<~RUBY).find_module_named("Foo").find_method("bar", false)
        module Foo # line 1
          def qux; end
          alias bar qux
        end
      RUBY

      source_code, _source_url = @helpers.method_source_code_and_url(method)

      _(source_code).must_be_nil
      # Unfortunately, _source_url is also nil because RDoc does not provide the
      # source code location in this case.
    end

    it "returns nil GitHub URL when options.github is false" do
      @helpers.options.github = false

      method = rdoc_top_level_for(<<~RUBY).find_module_named("Foo").find_method("bar", false)
        module Foo # line 1
          def bar; end # line 2
        end
      RUBY

      source_code, source_url = @helpers.method_source_code_and_url(method)

      _(source_code).must_match %r"# File .+\.rb, line 2\b"
      _(source_url).must_be_nil
    end
  end
end
