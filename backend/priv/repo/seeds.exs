# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
alias LivestokOs.{Inventory, Accounts, Repo, User}

# 0. Create a Super Admin (idempotent – skips if already exists)
case Repo.get_by(User, email: "admin@livestok.os") do
  nil ->
    {:ok, admin} =
      Accounts.create_user(%{
        "email" => "admin@livestok.os",
        "name" => "Super Admin",
        "password" => "admin123",
        "role" => "super_admin"
      })

    IO.puts("✅ Created Super Admin: #{admin.email}")

  existing ->
    IO.puts("ℹ️  Super Admin already exists: #{existing.email}")
end

# 1. Create a Farm
{:ok, farm} =
  Inventory.create_farm(%{
    name: "Rwanda Hills",
    type: "pasture_grazing",
    location: "Kigali"
  })

IO.puts("✅ Created Farm: #{farm.name}")

# 2. Create a Cow linked to that Farm
{:ok, cow} =
  Inventory.create_cow(%{
    name: "Bessie",
    tag_id: "COW-8842",
    breed: "Ankole",
    status: "healthy",
    birth_date: ~D[2023-01-01],
    farm_id: farm.id
  })

IO.puts("✅ Created Cow: #{cow.name} (Tag: #{cow.tag_id})")
