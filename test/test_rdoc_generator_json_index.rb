require 'rdoc/test_case'

class TestRDocGeneratorJsonIndex < RDoc::TestCase

  def setup
    super

    @tmpdir = File.join Dir.tmpdir, "test_rdoc_generator_darkfish_#{$$}"
    FileUtils.mkdir_p @tmpdir
    Dir.chdir @tmpdir

    @options = RDoc::Options.new
    @options.files = []
    # JsonIndex is used in conjunction with another generator
    @options.setup_generator 'darkfish'
    @options.op_dir = @tmpdir
    @options.option_parser = OptionParser.new
    @options.finish

    @darkfish = RDoc::Generator::Darkfish.new @options
    @g = RDoc::Generator::JsonIndex.new @darkfish, @options

    @rdoc = RDoc::RDoc.new
    @rdoc.options = @options
    @rdoc.generator = @g
    RDoc::RDoc.current = @rdoc

    @top_level = RDoc::TopLevel.new 'file.rb'
    @top_level.parser = RDoc::Parser::Ruby

    @klass = @top_level.add_class RDoc::NormalClass, 'C'

    @meth = @klass.add_method RDoc::AnyMethod.new(nil, 'meth')
    @meth.record_location @top_level

    @nest_klass = @klass.add_class RDoc::NormalClass, 'D'
    @nest_klass.record_location @top_level

    @nest_meth = @nest_klass.add_method RDoc::AnyMethod.new(nil, 'meth')

    @ignored = @top_level.add_class RDoc::NormalClass, 'Ignored'
    @ignored.ignore

    @page = RDoc::TopLevel.new 'page.rdoc'
    @page.parser = RDoc::Parser::Simple

    @top_levels = [@top_level, @page].sort
    @klasses    = [@klass, @nest_klass, @ignored]
  end

  def teardown
    super

    Dir.chdir @pwd
    FileUtils.rm_rf @tmpdir
  end

  def assert_file path
    assert File.file?(path), "#{path} is not a file"
  end

  def mu_pp obj
    s = ''
    s = PP.pp obj, s
    s = s.force_encoding Encoding.default_external if defined? Encoding
    s.chomp
  end

  def test_class_dir
    assert_equal @darkfish.class_dir, @g.class_dir
  end

  def test_file_dir
    assert_equal @darkfish.file_dir, @g.file_dir
  end

  def test_generate
    @g.generate @top_levels

    assert_file 'js/search_index.js'

    json = File.read 'js/search_index.js'

    json =~ /\Avar search_data = /

    assignment = $&
    index = $'

    refute_empty assignment

    index = JSON.parse index

    info = [
      @klass.search_record,
      @nest_klass.search_record,
      @meth.search_record,
      @nest_meth.search_record,
      @page.search_record,
    ]

    expected = {
      'index' => {
        'searchIndex' => [
          'c',
          'd',
          'meth()',
          'page.rdoc',
        ],
        'longSearchIndex' => [
          'file.rb',
          'c',
          'c::d',
          'page_rdoc.html',
        ],
        'info' => info,
      },
    }

    assert_equal expected, index
  end

  def test_index_classes
    @g.reset @top_levels, @klasses

    @g.index_classes

    expected = {
      :searchIndex     => %w[c d],
      :longSearchIndex => %w[file.rb c],
      :info            => [
        @klass.search_record,
        @nest_klass.search_record,
      ],
    }

    assert_equal expected, @g.index
  end

  def test_index_classes_nodoc
    @klass.document_self      = false
    @nest_klass.document_self = false
    @meth.document_self       = false
    @nest_meth.document_self  = false

    @g.reset @top_levels, @klasses

    @g.index_classes

    expected = {
      :searchIndex     => [],
      :longSearchIndex => [],
      :info            => [],
    }

    assert_equal expected, @g.index
  end

  def test_index_methods
    @g.reset @top_levels, @klasses

    @g.index_methods

    expected = {
      :searchIndex     => %w[meth() meth()],
      :longSearchIndex => %w[c c::d],
      :info            => [
        @meth.search_record,
        @nest_meth.search_record,
      ],
    }

    assert_equal expected, @g.index
  end

  def test_index_pages
    @g.reset @top_levels, @klasses

    @g.index_pages

    expected = {
      :searchIndex     => %w[page.rdoc],
      :longSearchIndex => %w[page_rdoc.html],
      :info            => [@page.search_record],
    }

    assert_equal expected, @g.index
  end

  def test_search_string
    assert_equal 'cd', @g.search_string('C d')
  end

end
