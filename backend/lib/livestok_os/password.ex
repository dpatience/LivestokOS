defmodule LivestokOs.Password do
  @moduledoc """
  Secure password hashing using PBKDF2-SHA256 with OWASP-recommended parameters.

  Format: `$pbkdf2-sha256$iterations$base64_salt$base64_hash`

  Uses `:crypto.pbkdf2_hmac/5` which is available in OTP 24+.
  """

  @iterations 600_000
  @salt_length 16
  @hash_length 32

  @doc """
  Hashes a plaintext password with a random salt.
  Returns a formatted hash string.
  """
  def hash(password) when is_binary(password) do
    salt = :crypto.strong_rand_bytes(@salt_length)
    hash = :crypto.pbkdf2_hmac(:sha256, password, salt, @iterations, @hash_length)

    "$pbkdf2-sha256$#{@iterations}$#{Base.encode64(salt)}$#{Base.encode64(hash)}"
  end

  @doc """
  Verifies a password against a stored hash string.
  Returns `true` if the password matches.
  """
  def verify(password, stored_hash) when is_binary(password) and is_binary(stored_hash) do
    case parse_hash(stored_hash) do
      {:ok, iterations, salt, expected_hash} ->
        computed =
          :crypto.pbkdf2_hmac(:sha256, password, salt, iterations, byte_size(expected_hash))

        secure_compare(computed, expected_hash)

      :error ->
        # Constant-time dummy to prevent timing attacks
        dummy_salt = :crypto.strong_rand_bytes(@salt_length)
        _ = :crypto.pbkdf2_hmac(:sha256, password, dummy_salt, @iterations, @hash_length)
        false
    end
  end

  def verify(_, _), do: false

  @doc """
  Performs a constant-time dummy hash to prevent user-enumeration timing attacks.
  Call this when the user is not found.
  """
  def no_user_verify do
    dummy_salt = :crypto.strong_rand_bytes(@salt_length)
    _ = :crypto.pbkdf2_hmac(:sha256, "dummy", dummy_salt, @iterations, @hash_length)
    false
  end

  # ---------------------------------------------------------------------------

  defp parse_hash("$pbkdf2-sha256$" <> rest) do
    case String.split(rest, "$", parts: 3) do
      [iter_str, salt_b64, hash_b64] ->
        with {iterations, _} <- Integer.parse(iter_str),
             {:ok, salt} <- Base.decode64(salt_b64),
             {:ok, hash} <- Base.decode64(hash_b64) do
          {:ok, iterations, salt, hash}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  # Legacy format: base64(salt <> hash) — supports migrating old hashes
  defp parse_hash(stored) do
    case Base.decode64(stored) do
      {:ok, <<salt::binary-size(@salt_length), hash::binary-size(@hash_length)>>} ->
        {:ok, 1000, salt, hash}

      _ ->
        :error
    end
  end

  defp secure_compare(a, b) when byte_size(a) == byte_size(b) do
    :crypto.hash_equals(a, b)
  end

  defp secure_compare(_, _), do: false
end
