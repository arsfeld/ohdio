defmodule OhdioWeb.LibraryLiveTest do
  use OhdioWeb.ConnCase

  import Phoenix.LiveViewTest
  import Ohdio.LibraryFixtures

  describe "Index" do
    test "displays library page", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/library")

      assert html =~ "Library"
      assert html =~ "Browse and play your downloaded audiobooks"
    end

    test "displays empty state when no audiobooks", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/library")

      assert html =~ "No audiobooks found"
    end

    test "displays completed audiobooks in grid", %{conn: conn} do
      audiobook =
        audiobook_fixture(%{
          status: :completed,
          title: "Test Audiobook",
          author: "Test Author"
        })

      {:ok, _view, html} = live(conn, ~p"/library")

      assert html =~ audiobook.title
      assert html =~ audiobook.author
    end

    test "does not display pending audiobooks", %{conn: conn} do
      _pending =
        audiobook_fixture(%{
          status: :pending,
          title: "Pending Book",
          author: "Pending Author"
        })

      {:ok, _view, html} = live(conn, ~p"/library")

      refute html =~ "Pending Book"
      assert html =~ "No audiobooks found"
    end

    test "searches audiobooks by title", %{conn: conn} do
      _book1 =
        audiobook_fixture(%{
          status: :completed,
          title: "Harry Potter",
          author: "J.K. Rowling"
        })

      _book2 =
        audiobook_fixture(%{
          status: :completed,
          title: "Lord of the Rings",
          author: "J.R.R. Tolkien",
          url: "https://example.com/lotr"
        })

      {:ok, view, _html} = live(conn, ~p"/library")

      html =
        view
        |> form("#search-form", search: "Harry")
        |> render_change()

      assert html =~ "Harry Potter"
      refute html =~ "Lord of the Rings"
    end

    test "searches audiobooks by author", %{conn: conn} do
      _book1 =
        audiobook_fixture(%{
          status: :completed,
          title: "Harry Potter",
          author: "J.K. Rowling"
        })

      _book2 =
        audiobook_fixture(%{
          status: :completed,
          title: "Lord of the Rings",
          author: "J.R.R. Tolkien",
          url: "https://example.com/lotr"
        })

      {:ok, view, _html} = live(conn, ~p"/library")

      html =
        view
        |> form("#search-form", search: "Tolkien")
        |> render_change()

      assert html =~ "Lord of the Rings"
      refute html =~ "Harry Potter"
    end

    test "sorts audiobooks by title", %{conn: conn} do
      _book1 = audiobook_fixture(%{status: :completed, title: "Zebra", author: "Author A"})

      _book2 =
        audiobook_fixture(%{
          status: :completed,
          title: "Apple",
          author: "Author B",
          url: "https://example.com/apple"
        })

      {:ok, view, _html} = live(conn, ~p"/library")

      html =
        view
        |> element("button", "Title")
        |> render_click()

      # Check that Apple appears before Zebra in the HTML
      apple_pos = :binary.match(html, "Apple") |> elem(0)
      zebra_pos = :binary.match(html, "Zebra") |> elem(0)
      assert apple_pos < zebra_pos
    end

    test "opens audiobook detail modal", %{conn: conn} do
      audiobook =
        audiobook_fixture(%{
          status: :completed,
          title: "Test Book",
          author: "Test Author",
          narrator: "Test Narrator"
        })

      {:ok, view, _html} = live(conn, ~p"/library")

      html =
        view
        |> element("div[phx-value-id='#{audiobook.id}']")
        |> render_click()

      assert html =~ "Test Book"
      assert html =~ "Test Author"
      assert html =~ "Narrated by Test Narrator"
      assert html =~ "modal-open"
    end

    test "closes audiobook detail modal", %{conn: conn} do
      audiobook =
        audiobook_fixture(%{status: :completed, title: "Test Book", author: "Test Author"})

      {:ok, view, _html} = live(conn, ~p"/library")

      # Open modal
      view
      |> element("div[phx-value-id='#{audiobook.id}']")
      |> render_click()

      # Close modal
      html =
        view
        |> element("button[phx-click='close_modal']")
        |> render_click()

      refute html =~ "modal-open"
    end
  end

  describe "Bulk Download" do
    test "displays bulk actions toolbar when audiobooks exist", %{conn: conn} do
      audiobook_fixture(%{status: :completed, title: "Test Book", author: "Test Author"})

      {:ok, _view, html} = live(conn, ~p"/library")

      assert html =~ "Select All"
    end

    test "does not display bulk actions toolbar when no audiobooks", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/library")

      refute html =~ "Select All"
    end

    test "selects and deselects audiobooks", %{conn: conn} do
      audiobook =
        audiobook_fixture(%{status: :completed, title: "Test Book", author: "Test Author"})

      {:ok, view, _html} = live(conn, ~p"/library")

      # Select audiobook
      html =
        view
        |> element("input[type='checkbox'][phx-value-id='#{audiobook.id}']")
        |> render_click()

      assert html =~ "1 selected"

      # Deselect audiobook
      html =
        view
        |> element("input[type='checkbox'][phx-value-id='#{audiobook.id}']")
        |> render_click()

      refute html =~ "selected"
    end

    test "selects all audiobooks", %{conn: conn} do
      audiobook_fixture(%{status: :completed, title: "Book 1", author: "Author 1"})

      audiobook_fixture(%{
        status: :completed,
        title: "Book 2",
        author: "Author 2",
        url: "https://example.com/book2"
      })

      {:ok, view, _html} = live(conn, ~p"/library")

      html =
        view
        |> element("button", "Select All")
        |> render_click()

      assert html =~ "2 selected"
      assert html =~ "Deselect All"
    end

    test "deselects all audiobooks", %{conn: conn} do
      audiobook_fixture(%{status: :completed, title: "Book 1", author: "Author 1"})

      {:ok, view, _html} = live(conn, ~p"/library")

      # Select all
      view
      |> element("button", "Select All")
      |> render_click()

      # Deselect all
      html =
        view
        |> element("button", "Deselect All")
        |> render_click()

      refute html =~ "selected"
      assert html =~ "Select All"
    end

    test "bulk downloads selected audiobooks", %{conn: conn} do
      audiobook1 =
        audiobook_fixture(%{status: :completed, title: "Book 1", author: "Author 1"})

      audiobook2 =
        audiobook_fixture(%{
          status: :completed,
          title: "Book 2",
          author: "Author 2",
          url: "https://example.com/book2"
        })

      {:ok, view, _html} = live(conn, ~p"/library")

      # Select audiobooks
      view
      |> element("input[type='checkbox'][phx-value-id='#{audiobook1.id}']")
      |> render_click()

      view
      |> element("input[type='checkbox'][phx-value-id='#{audiobook2.id}']")
      |> render_click()

      # Trigger bulk download
      html =
        view
        |> element("button", "Download Selected")
        |> render_click()

      assert html =~ "2 audiobooks added to download queue"

      # Verify queue items were created
      queue_items = Ohdio.Downloads.list_queue_items()
      assert length(queue_items) == 2
      assert Enum.any?(queue_items, &(&1.audiobook_id == audiobook1.id))
      assert Enum.any?(queue_items, &(&1.audiobook_id == audiobook2.id))
    end

    test "shows error when trying to bulk download with no selection", %{conn: conn} do
      audiobook_fixture(%{status: :completed, title: "Book 1", author: "Author 1"})

      {:ok, view, _html} = live(conn, ~p"/library")

      # Try to bulk download without selecting anything
      html =
        view
        |> element("button", "Download Selected")
        |> render_click()

      assert html =~ "No audiobooks selected"
    end

    test "clears selection after successful bulk download", %{conn: conn} do
      audiobook =
        audiobook_fixture(%{status: :completed, title: "Book 1", author: "Author 1"})

      {:ok, view, _html} = live(conn, ~p"/library")

      # Select audiobook
      view
      |> element("input[type='checkbox'][phx-value-id='#{audiobook.id}']")
      |> render_click()

      # Trigger bulk download
      html =
        view
        |> element("button", "Download Selected")
        |> render_click()

      # Selection should be cleared
      refute html =~ "selected"
    end

    test "handles duplicate queue items gracefully", %{conn: conn} do
      audiobook =
        audiobook_fixture(%{status: :completed, title: "Book 1", author: "Author 1"})

      # Create a queue item first
      Ohdio.Downloads.create_queue_item(%{audiobook_id: audiobook.id})

      {:ok, view, _html} = live(conn, ~p"/library")

      # Select and try to download
      view
      |> element("input[type='checkbox'][phx-value-id='#{audiobook.id}']")
      |> render_click()

      html =
        view
        |> element("button", "Download Selected")
        |> render_click()

      # Should show error or partial success
      assert html =~ "may already be queued"
    end
  end
end
