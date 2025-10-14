defmodule Ohdio.LibraryTest do
  use Ohdio.DataCase

  alias Ohdio.Library

  describe "audiobooks" do
    alias Ohdio.Library.Audiobook

    import Ohdio.LibraryFixtures

    @invalid_attrs %{
      status: nil,
      author: nil,
      title: nil,
      url: nil,
      narrator: nil,
      cover_image_url: nil,
      duration: nil,
      file_size: nil,
      file_path: nil
    }

    test "list_audiobooks/0 returns all audiobooks" do
      audiobook = audiobook_fixture()
      assert Library.list_audiobooks() == [audiobook]
    end

    test "get_audiobook!/1 returns the audiobook with given id" do
      audiobook = audiobook_fixture()
      assert Library.get_audiobook!(audiobook.id) == audiobook
    end

    test "create_audiobook/1 with valid data creates a audiobook" do
      valid_attrs = %{
        status: "some status",
        author: "some author",
        title: "some title",
        url: "some url",
        narrator: "some narrator",
        cover_image_url: "some cover_image_url",
        duration: 42,
        file_size: 42,
        file_path: "some file_path"
      }

      assert {:ok, %Audiobook{} = audiobook} = Library.create_audiobook(valid_attrs)
      assert audiobook.status == "some status"
      assert audiobook.author == "some author"
      assert audiobook.title == "some title"
      assert audiobook.url == "some url"
      assert audiobook.narrator == "some narrator"
      assert audiobook.cover_image_url == "some cover_image_url"
      assert audiobook.duration == 42
      assert audiobook.file_size == 42
      assert audiobook.file_path == "some file_path"
    end

    test "create_audiobook/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Library.create_audiobook(@invalid_attrs)
    end

    test "update_audiobook/2 with valid data updates the audiobook" do
      audiobook = audiobook_fixture()

      update_attrs = %{
        status: "some updated status",
        author: "some updated author",
        title: "some updated title",
        url: "some updated url",
        narrator: "some updated narrator",
        cover_image_url: "some updated cover_image_url",
        duration: 43,
        file_size: 43,
        file_path: "some updated file_path"
      }

      assert {:ok, %Audiobook{} = audiobook} = Library.update_audiobook(audiobook, update_attrs)
      assert audiobook.status == "some updated status"
      assert audiobook.author == "some updated author"
      assert audiobook.title == "some updated title"
      assert audiobook.url == "some updated url"
      assert audiobook.narrator == "some updated narrator"
      assert audiobook.cover_image_url == "some updated cover_image_url"
      assert audiobook.duration == 43
      assert audiobook.file_size == 43
      assert audiobook.file_path == "some updated file_path"
    end

    test "update_audiobook/2 with invalid data returns error changeset" do
      audiobook = audiobook_fixture()
      assert {:error, %Ecto.Changeset{}} = Library.update_audiobook(audiobook, @invalid_attrs)
      assert audiobook == Library.get_audiobook!(audiobook.id)
    end

    test "delete_audiobook/1 deletes the audiobook" do
      audiobook = audiobook_fixture()
      assert {:ok, %Audiobook{}} = Library.delete_audiobook(audiobook)
      assert_raise Ecto.NoResultsError, fn -> Library.get_audiobook!(audiobook.id) end
    end

    test "change_audiobook/1 returns a audiobook changeset" do
      audiobook = audiobook_fixture()
      assert %Ecto.Changeset{} = Library.change_audiobook(audiobook)
    end

    test "list_completed_audiobooks/1 returns only completed audiobooks" do
      # Create a completed audiobook
      completed =
        audiobook_fixture(%{status: :completed, title: "Completed Book", author: "Author A"})

      # Create a pending audiobook
      _pending =
        audiobook_fixture(%{
          status: :pending,
          title: "Pending Book",
          author: "Author B",
          url: "https://example.com/different"
        })

      results = Library.list_completed_audiobooks()
      assert length(results) == 1
      assert hd(results).id == completed.id
    end

    test "list_completed_audiobooks/1 with search filters by title" do
      _book1 =
        audiobook_fixture(%{status: :completed, title: "Harry Potter", author: "J.K. Rowling"})

      _book2 =
        audiobook_fixture(%{
          status: :completed,
          title: "Lord of the Rings",
          author: "J.R.R. Tolkien",
          url: "https://example.com/lotr"
        })

      results = Library.list_completed_audiobooks(search: "Harry")
      assert length(results) == 1
      assert hd(results).title == "Harry Potter"
    end

    test "list_completed_audiobooks/1 with search filters by author" do
      _book1 =
        audiobook_fixture(%{status: :completed, title: "Harry Potter", author: "J.K. Rowling"})

      _book2 =
        audiobook_fixture(%{
          status: :completed,
          title: "Lord of the Rings",
          author: "J.R.R. Tolkien",
          url: "https://example.com/lotr"
        })

      results = Library.list_completed_audiobooks(search: "Tolkien")
      assert length(results) == 1
      assert hd(results).title == "Lord of the Rings"
    end

    test "list_completed_audiobooks/1 sorts by title ascending" do
      _book1 = audiobook_fixture(%{status: :completed, title: "Zebra", author: "Author A"})

      _book2 =
        audiobook_fixture(%{
          status: :completed,
          title: "Apple",
          author: "Author B",
          url: "https://example.com/apple"
        })

      results = Library.list_completed_audiobooks(sort_by: :title, sort_order: :asc)
      assert length(results) == 2
      assert Enum.at(results, 0).title == "Apple"
      assert Enum.at(results, 1).title == "Zebra"
    end

    test "list_completed_audiobooks/1 sorts by author descending" do
      _book1 = audiobook_fixture(%{status: :completed, title: "Book A", author: "Albert"})

      _book2 =
        audiobook_fixture(%{
          status: :completed,
          title: "Book B",
          author: "Zoe",
          url: "https://example.com/bookb"
        })

      results = Library.list_completed_audiobooks(sort_by: :author, sort_order: :desc)
      assert length(results) == 2
      assert Enum.at(results, 0).author == "Zoe"
      assert Enum.at(results, 1).author == "Albert"
    end
  end
end
