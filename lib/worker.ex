defmodule Metex.Worker do
    use GenServer
    import Metex.Keys

    ## CLIENT API
    def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, :ok, opts) # invoke .init and ait for response
    end

    def get_temperature(pid, location) do
        GenServer.call( pid, {:location, location} ) # 'call' - synchro ; 'cast' - asynchro
    end

    def get_stats(pid) do
        GenServer.call(pid, :get_stats) # calls tag from server's pid
    end

    def reset_stats(pid) do
        GenServer.cast(pid, :reset_stats)
    end

    def stop(pid) do
        GenServer.cast(pid, :stop)
    end


    ## SERVER CALLBACKS
    def init(:ok) do
        { :ok, %{} } # %{} - to keep frequency of requested locations
    end
    # It starts the process and also links the server
    # process to the parent process. This means if
    # the server process fails for some reason,
    # the parent process is notified.

    def handle_call({:location, location}, _from, stats) do
        case temperature_of(location) do
            { :ok, temp } ->
                new_stats = update_stats(stats, location)
                { :reply, "#{temp}C", new_stats}
            _ ->
                {:reply, :error, stats}
        end
    end

    def handle_call(:get_stats, _from, stats) do
        {:reply, stats, stats} # third arg to keep unchanged
    end
    # iex(9)> Metex.Worker.get_stats pid
    # %{"Brunei" => 2, "Cambodia" => 1, "Malaysia" => 1, "Singapore" => 3}

    def handle_cast(:reset_stats, _stats) do
        {:noreply, %{}} # thats why it's an asynch request
    end
    # iex(10)> Metex.Worker.reset_stats pid
    # :ok
    # iex(11)> Metex.Worker.get_stats pid
    # %{}
    def handle_cast(:stop, stats) do
        {:stop, :normal, stats}
    end

    def terminate(reason, stats) do # if want: save to db; to .txt; etc...
        IO.puts "server termitated b.of #{inspect reason}"
            inspect stats
        :ok
    end

    def handle_info(msg, stats) do
        IO.puts "received #{inspect msg}"
        {:noreply, stats}
    end
    # iex> send pid, "It's raining men"
    # received "It's raining men"


    ## Helper functions
    defp temperature_of(location) do
        url_for(location) |> HTTPoison.get |> parse_response
    end

    defp url_for(location) do
        "http://api.openweathermap.org/data/2.5/weather?q=#{location}&APPID=#{apikey}"
    end

    defp parse_response({ :ok, %HTTPoison.Response{body: body, status_code: 200} }) do
        body |> JSON.decode! |> compute_temperature
    end

    defp parse_response(_) do
        :error
    end

    defp compute_temperature(json) do
        try do
            temp = (json["main"]["temp"] - 273.15) |> Float.round(1)
            {:ok, temp}
        catch
            _,_ ->  :error
        end
    end

    defp update_stats(old_stats, location) do
        case Map.has_key?(old_stats, location)   do
            true ->
                Map.update!(old_stats, location, &(&1 + 1))
            false ->
                Map.put_new(old_stats, location, 1)
        end
    end

end
