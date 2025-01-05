defmodule Pling.Services.NDJsonStreamTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Pling.Services.NDJsonStream

  describe "stream_fn/1" do
    test "processes complete objects" do
      test_pid = self()
      stream_fn = NDJsonStream.stream_fn(fn obj -> send(test_pid, {:object, obj}) end)

      {:cont, buffer} = stream_fn.({:data, ~s({"id": 1, "name": "test"}\n)}, "")
      assert_received {:object, %{"id" => 1, "name" => "test"}}
      assert buffer == ""
    end

    test "handles multiple objects in one chunk" do
      test_pid = self()
      stream_fn = NDJsonStream.stream_fn(fn obj -> send(test_pid, {:object, obj}) end)

      {:cont, buffer} = stream_fn.({:data, ~s({"id": 1}\n{"id": 2}\n)}, "")
      assert_received {:object, %{"id" => 1}}
      assert_received {:object, %{"id" => 2}}
      assert buffer == ""
    end

    test "handles partial objects across chunks" do
      test_pid = self()
      stream_fn = NDJsonStream.stream_fn(fn obj -> send(test_pid, {:object, obj}) end)

      {:cont, buffer1} = stream_fn.({:data, ~s({"id": 1, "na)}, "")
      refute_received {:object, _}
      assert buffer1 == ~s({"id": 1, "na)

      {:cont, buffer2} = stream_fn.({:data, ~s(me": "test"}\n)}, buffer1)
      assert_received {:object, %{"id" => 1, "name" => "test"}}
      assert buffer2 == ""
    end

    test "handles invalid JSON gracefully" do
      test_pid = self()
      stream_fn = NDJsonStream.stream_fn(fn obj -> send(test_pid, {:object, obj}) end)

      capture_log(fn ->
        {:cont, _} = stream_fn.({:data, ~s({"valid": true}\n{invalid}\n{"also_valid": 1}\n)}, "")
      end)

      assert_received {:object, %{"valid" => true}}
      assert_received {:object, %{"also_valid" => 1}}
      refute_received {:object, _}
    end

    test "processes final buffer on done" do
      test_pid = self()
      stream_fn = NDJsonStream.stream_fn(fn obj -> send(test_pid, {:object, obj}) end)

      {:cont, buffer} = stream_fn.({:data, ~s({"id": 1}\n{"id": 2})}, "")
      assert_received {:object, %{"id" => 1}}

      {:cont, _} = stream_fn.({:done, nil}, buffer)
      assert_received {:object, %{"id" => 2}}
    end

    test "ignores unknown messages" do
      test_pid = self()
      stream_fn = NDJsonStream.stream_fn(fn obj -> send(test_pid, {:object, obj}) end)

      {:cont, buffer} = stream_fn.(:unknown, "some buffer")
      assert buffer == "some buffer"
      refute_received {:object, _}
    end
  end
end
