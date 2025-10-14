defmodule OhdioWeb.HomeLiveTest do
  use OhdioWeb.ConnCase
  use Oban.Testing, repo: Ohdio.Repo

  import Phoenix.LiveViewTest

  describe "Home page" do
    test "displays the home page with form", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      # AC #1: HomeLive created with URL input form
      assert html =~ "OHdio Downloader"
      assert has_element?(view, "#download-form")
      assert has_element?(view, "input[name='download[url]']")
      assert has_element?(view, "button[type='submit']")
    end

    test "displays supported URL types section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # AC #4: Examples section shows supported URL types
      assert html =~ "Supported URL Types"
      assert html =~ "OHdio Category Pages"
      assert html =~ "OHdio Individual Audiobooks"
      assert html =~ "Generic Media URLs"
      assert html =~ "youtube.com"
      assert html =~ "vimeo.com"
      assert html =~ "soundcloud.com"
    end

    test "shows error for empty URL submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Submit empty form
      view
      |> form("#download-form", download: %{url: ""})
      |> render_submit()

      # AC #3 & #6: Error feedback via put_flash
      assert has_element?(view, ".alert-error")
      flash_html = render(view)
      assert flash_html =~ "Please enter a URL"
    end

    test "detects and enqueues OHdio category URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      category_url = "https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse"

      # AC #2: Form submission detects URL type and enqueues worker
      view
      |> form("#download-form", download: %{url: category_url})
      |> render_submit()

      # AC #3 & #6: Success feedback via put_flash
      assert has_element?(view, ".alert-info")
      flash_html = render(view)
      assert flash_html =~ "OHdio category detected"

      # Verify Oban job was created
      assert_enqueued(worker: Ohdio.Workers.CategoryScrapeWorker)
    end

    test "detects and enqueues OHdio audiobook URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      audiobook_url = "https://ici.radio-canada.ca/ohdio/livres-audio/12345/test-book"

      # AC #2: Form submission detects URL type and enqueues worker
      view
      |> form("#download-form", download: %{url: audiobook_url})
      |> render_submit()

      # AC #3 & #6: Success feedback via put_flash
      assert has_element?(view, ".alert-info")
      flash_html = render(view)
      assert flash_html =~ "OHdio audiobook detected"

      # Verify audiobook was created
      audiobooks = Ohdio.Library.list_audiobooks()
      assert length(audiobooks) == 1
      assert List.first(audiobooks).url == audiobook_url

      # Verify Oban job was created
      assert_enqueued(worker: Ohdio.Workers.MetadataExtractWorker)
    end

    test "detects and enqueues generic YouTube URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      youtube_url = "https://www.youtube.com/watch?v=test123"

      # AC #2: Form submission detects URL type and enqueues worker
      view
      |> form("#download-form", download: %{url: youtube_url})
      |> render_submit()

      # AC #3 & #6: Success feedback via put_flash
      assert has_element?(view, ".alert-info")
      flash_html = render(view)
      assert flash_html =~ "Generic media URL detected"

      # Verify audiobook was created
      audiobooks = Ohdio.Library.list_audiobooks()
      assert length(audiobooks) == 1
      assert List.first(audiobooks).url == youtube_url

      # Verify Oban job was created
      assert_enqueued(worker: Ohdio.Workers.MetadataExtractWorker)
    end

    test "handles unknown URL type gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      unknown_url = "https://example.com/some-media"

      # AC #2: Form submission detects URL type and attempts download
      view
      |> form("#download-form", download: %{url: unknown_url})
      |> render_submit()

      # AC #3 & #6: Info feedback via put_flash (attempting with yt-dlp)
      assert has_element?(view, ".alert-info")
      flash_html = render(view)
      assert flash_html =~ "Unknown URL type"
      assert flash_html =~ "attempting download"

      # Verify audiobook was created
      audiobooks = Ohdio.Library.list_audiobooks()
      assert length(audiobooks) == 1
      assert List.first(audiobooks).url == unknown_url

      # Verify Oban job was created
      assert_enqueued(worker: Ohdio.Workers.MetadataExtractWorker)
    end

    test "resets form after successful submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      category_url = "https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse"

      # Submit form
      view
      |> form("#download-form", download: %{url: category_url})
      |> render_submit()

      # Verify form is reset
      html = render(view)
      refute html =~ category_url
    end

    test "validates URL format during input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # AC #1: URL input form with validation
      view
      |> form("#download-form", download: %{url: "https://example.com/test"})
      |> render_change()

      # Form should accept valid input without errors
      refute has_element?(view, ".alert-error")
    end

    test "applies Tailwind CSS styling", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # AC #5: Tailwind CSS styling applied
      assert html =~ "card"
      assert html =~ "btn"
      assert html =~ "input"
      assert html =~ "bg-base-200"
      assert html =~ "shadow-xl"
    end
  end
end
