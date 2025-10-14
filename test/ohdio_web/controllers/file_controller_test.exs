defmodule OhdioWeb.FileControllerTest do
  use OhdioWeb.ConnCase

  import Ohdio.LibraryFixtures

  describe "audio/2" do
    setup do
      # Create a temporary test audio file
      tmp_dir = System.tmp_dir!()
      test_file = Path.join(tmp_dir, "test_audio_#{:rand.uniform(1_000_000)}.mp3")
      File.write!(test_file, "fake audio content for testing")

      on_exit(fn ->
        if File.exists?(test_file), do: File.rm!(test_file)
      end)

      %{test_file: test_file}
    end

    test "serves audio file without range header", %{conn: conn, test_file: test_file} do
      audiobook =
        audiobook_fixture(%{
          status: :completed,
          title: "Test Audio",
          author: "Test Author",
          file_path: test_file
        })

      conn = get(conn, ~p"/files/audio/#{audiobook.id}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["audio/mpeg"]
      assert get_resp_header(conn, "accept-ranges") == ["bytes"]
      assert conn.resp_body == "fake audio content for testing"
    end

    test "serves audio file with range header", %{conn: conn, test_file: test_file} do
      audiobook =
        audiobook_fixture(%{
          status: :completed,
          title: "Test Audio",
          author: "Test Author",
          file_path: test_file
        })

      conn =
        conn
        |> put_req_header("range", "bytes=0-4")
        |> get(~p"/files/audio/#{audiobook.id}")

      assert conn.status == 206
      assert get_resp_header(conn, "content-type") == ["audio/mpeg"]
      assert get_resp_header(conn, "accept-ranges") == ["bytes"]
      assert ["bytes 0-4/" <> _] = get_resp_header(conn, "content-range")
      assert conn.resp_body == "fake "
    end

    test "returns 404 when file does not exist", %{conn: conn} do
      audiobook =
        audiobook_fixture(%{
          status: :completed,
          title: "Test Audio",
          author: "Test Author",
          file_path: "/nonexistent/file.mp3"
        })

      conn = get(conn, ~p"/files/audio/#{audiobook.id}")

      assert conn.status == 404
      assert json_response(conn, 404)["error"] == "File not found"
    end

    test "returns 404 when audiobook has no file_path", %{conn: conn} do
      audiobook =
        audiobook_fixture(%{
          status: :completed,
          title: "Test Audio",
          author: "Test Author",
          file_path: nil
        })

      conn = get(conn, ~p"/files/audio/#{audiobook.id}")

      assert conn.status == 404
      assert json_response(conn, 404)["error"] == "File not found"
    end

    test "handles different audio formats", %{conn: conn} do
      tmp_dir = System.tmp_dir!()
      test_m4a = Path.join(tmp_dir, "test_audio_#{:rand.uniform(1_000_000)}.m4a")
      File.write!(test_m4a, "fake m4a content")

      audiobook =
        audiobook_fixture(%{
          status: :completed,
          title: "Test Audio",
          author: "Test Author",
          file_path: test_m4a,
          url: "https://example.com/m4a"
        })

      conn = get(conn, ~p"/files/audio/#{audiobook.id}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["audio/mp4"]

      File.rm!(test_m4a)
    end
  end

  describe "cover/2" do
    test "redirects to external cover image URL", %{conn: conn} do
      audiobook =
        audiobook_fixture(%{
          status: :completed,
          title: "Test Audio",
          author: "Test Author",
          cover_image_url: "https://example.com/cover.jpg"
        })

      conn = get(conn, ~p"/files/cover/#{audiobook.id}")

      assert redirected_to(conn) == "https://example.com/cover.jpg"
    end

    test "returns 404 when no cover image", %{conn: conn} do
      audiobook =
        audiobook_fixture(%{
          status: :completed,
          title: "Test Audio",
          author: "Test Author",
          cover_image_url: nil
        })

      conn = get(conn, ~p"/files/cover/#{audiobook.id}")

      assert conn.status == 404
      assert json_response(conn, 404)["error"] == "Cover image not found"
    end
  end
end
