# frozen_string_literal: true

require "cases/helper"
require "models/person"
require "models/topic"
require "pp"
require "models/cpk"

class NonExistentTable < ActiveRecord::Base; end
class PkWithDefault < ActiveRecord::Base; end

class CoreTest < ActiveRecord::TestCase
  fixtures :topics, :cpk_books

  def test_eql_on_default_pk
    saved_record = PkWithDefault.new
    saved_record.save!
    assert_equal 123, saved_record.id

    record = PkWithDefault.new
    assert_equal 123, record.id

    record2 = PkWithDefault.new
    assert_equal 123, record2.id

    assert     record.eql?(record),       "record should eql? itself"
    assert_not record.eql?(saved_record), "new record should not eql? saved"
    assert_not saved_record.eql?(record), "saved record should not eql? new"
    assert_not record.eql?(record2),      "new record should not eql? new record"
    assert_not record2.eql?(record),      "new record should not eql? new record"
  end

  def test_inspect_class
    assert_equal "ActiveRecord::Base", ActiveRecord::Base.inspect
    assert_equal "LoosePerson(abstract)", LoosePerson.inspect
    assert_match(/^Topic\(id: integer, title: string/, Topic.inspect)
  end

  def test_inspect_instance
    topic = topics(:first)
    assert_equal %(#<Topic id: 1, title: "The First Topic", author_name: "David", author_email_address: "david@loudthinking.com", written_on: "#{topic.written_on.to_fs(:inspect)}", bonus_time: "#{topic.bonus_time.to_fs(:inspect)}", last_read: "#{topic.last_read.to_fs(:inspect)}", content: "Have a nice day", important: nil, approved: false, replies_count: 1, unique_replies_count: 0, parent_id: nil, parent_title: nil, type: nil, group: nil, created_at: "#{topic.created_at.to_fs(:inspect)}", updated_at: "#{topic.updated_at.to_fs(:inspect)}">), topic.inspect
  end

  def test_inspect_instance_with_lambda_date_formatter
    before = Time::DATE_FORMATS[:inspect]
    Time::DATE_FORMATS[:inspect] = ->(date) { "my_format" }
    topic = topics(:first)

    assert_equal %(#<Topic id: 1, title: "The First Topic", author_name: "David", author_email_address: "david@loudthinking.com", written_on: "my_format", bonus_time: "my_format", last_read: "2004-04-15", content: "Have a nice day", important: nil, approved: false, replies_count: 1, unique_replies_count: 0, parent_id: nil, parent_title: nil, type: nil, group: nil, created_at: "my_format", updated_at: "my_format">), topic.inspect

  ensure
    Time::DATE_FORMATS[:inspect] = before
  end

  def test_inspect_new_instance
    assert_match(/Topic id: nil/, Topic.new.inspect)
  end

  def test_inspect_limited_select_instance
    assert_equal %(#<Topic id: 1>), Topic.all.merge!(select: "id", where: "id = 1").first.inspect
    assert_equal %(#<Topic id: 1, title: "The First Topic">), Topic.all.merge!(select: "id, title", where: "id = 1").first.inspect
  end

  def test_inspect_instance_with_non_primary_key_id_attribute
    topic = topics(:first).becomes(TitlePrimaryKeyTopic)
    assert_match(/id: 1/, topic.inspect)
  end

  def test_inspect_class_without_table
    assert_equal "NonExistentTable(Table doesn't exist)", NonExistentTable.inspect
  end

  def test_inspect_relation_with_virtual_field
    relation = Topic.limit(1).select("1 as virtual_field")
    assert_match(/virtual_field: 1/, relation.inspect)
  end

  def test_pretty_print_new
    topic = Topic.new
    actual = +""
    PP.pp(topic, StringIO.new(actual))
    expected = <<~PRETTY
      #<Topic:0xXXXXXX
       id: nil,
       title: nil,
       author_name: nil,
       author_email_address: "test@test.com",
       written_on: nil,
       bonus_time: nil,
       last_read: nil,
       content: nil,
       important: nil,
       approved: true,
       replies_count: 0,
       unique_replies_count: 0,
       parent_id: nil,
       parent_title: nil,
       type: nil,
       group: nil,
       created_at: nil,
       updated_at: nil>
    PRETTY
    assert actual.start_with?(expected.split("XXXXXX").first)
    assert actual.end_with?(expected.split("XXXXXX").last)
  end

  def test_pretty_print_persisted
    topic = topics(:first)
    actual = +""
    PP.pp(topic, StringIO.new(actual))
    expected = <<~PRETTY
      #<Topic:0x\\w+
       id: 1,
       title: "The First Topic",
       author_name: "David",
       author_email_address: "david@loudthinking.com",
       written_on: 2003-07-16 14:28:11(?:\.2233)? UTC,
       bonus_time: 2000-01-01 14:28:00 UTC,
       last_read: Thu, 15 Apr 2004,
       content: "Have a nice day",
       important: nil,
       approved: false,
       replies_count: 1,
       unique_replies_count: 0,
       parent_id: nil,
       parent_title: nil,
       type: nil,
       group: nil,
       created_at: [^,]+,
       updated_at: [^,>]+>
    PRETTY
    assert_match(/\A#{expected}\z/, actual)
  end

  def test_pretty_print_uninitialized
    topic = Topic.allocate
    actual = +""
    PP.pp(topic, StringIO.new(actual))
    expected = "#<Topic:XXXXXX not initialized>\n"
    assert actual.start_with?(expected.split("XXXXXX").first)
    assert actual.end_with?(expected.split("XXXXXX").last)
  end

  def test_pretty_print_overridden_by_inspect
    subtopic = Class.new(Topic) do
      def inspect
        "inspecting topic"
      end
    end
    actual = +""
    PP.pp(subtopic.new, StringIO.new(actual))
    assert_equal "inspecting topic\n", actual
  end

  def test_pretty_print_with_non_primary_key_id_attribute
    topic = topics(:first).becomes(TitlePrimaryKeyTopic)
    actual = +""
    PP.pp(topic, StringIO.new(actual))
    assert_match(/id: 1/, actual)
  end

  def test_find_by_cache_does_not_duplicate_entries
    Topic.initialize_find_by_cache
    using_prepared_statements = Topic.connection.prepared_statements
    topic_find_by_cache = Topic.instance_variable_get("@find_by_statement_cache")[using_prepared_statements]

    assert_difference -> { topic_find_by_cache.size }, +1 do
      Topic.find(1)
    end
    assert_no_difference -> { topic_find_by_cache.size } do
      Topic.find_by(id: 1)
    end
  end

  def test_composite_pk_models_added_to_a_set
    library = Set.new
    # new record with primary key present
    library << Cpk::Book.new(author_id: 1, number: 2)

    # duplicate
    library << cpk_books(:cpk_great_author_first_book)
    library << cpk_books(:cpk_great_author_first_book)

    # without primary key being set
    library << Cpk::Book.new(title: "Book A")
    library << Cpk::Book.new(title: "Book B")

    assert_equal 4, library.size
  end

  def test_composite_pk_models_equality
    book = cpk_books(:cpk_great_author_first_book)
    book_instance_1 = Cpk::Book.find_by(author_id: book.author_id, number: book.number)
    book_instance_2 = Cpk::Book.find_by(author_id: book.author_id, number: book.number)

    assert book_instance_1 == book_instance_1
    assert book_instance_1 == book_instance_2

    # two new records with the same primary key
    assert_not Cpk::Book.new(author_id: 1, number: 2) == Cpk::Book.new(author_id: 1, number: 2)
    # two new records with an empty primary key values
    assert_not Cpk::Book.new == Cpk::Book.new
    # two persisted records with a different primary key
    assert_not cpk_books(:cpk_great_author_first_book) == cpk_books(:cpk_great_author_second_book)
  end

  def test_composite_pk_models_hash
    book = cpk_books(:cpk_great_author_first_book)
    book_instance_1 = Cpk::Book.find_by(author_id: book.author_id, number: book.number)
    book_instance_2 = Cpk::Book.find_by(author_id: book.author_id, number: book.number)

    assert_equal book_instance_1.hash, book_instance_1.hash
    assert_equal book_instance_1.hash, book_instance_2.hash

    # two new records with the same primary key
    assert_not_equal Cpk::Book.new(author_id: 1, number: 2).hash, Cpk::Book.new(author_id: 1, number: 2).hash
    # two new records with an empty primary key values
    assert_not_equal Cpk::Book.new.hash, Cpk::Book.new.hash
    # two persisted records with a different primary key
    assert_not_equal cpk_books(:cpk_great_author_first_book).hash, cpk_books(:cpk_great_author_second_book).hash
  end
end
