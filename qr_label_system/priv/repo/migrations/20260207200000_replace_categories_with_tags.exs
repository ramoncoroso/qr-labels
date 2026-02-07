defmodule QrLabelSystem.Repo.Migrations.ReplaceCategoriesWithTags do
  use Ecto.Migration

  def up do
    # 1. Create design_tags table
    create table(:design_tags) do
      add :name, :string, null: false
      add :color, :string, default: "#6366F1"
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:design_tags, [:user_id])
    create unique_index(:design_tags, [:user_id, :name])

    # 2. Create pivot table
    create table(:design_tag_assignments, primary_key: false) do
      add :design_id, references(:label_designs, on_delete: :delete_all), null: false
      add :tag_id, references(:design_tags, on_delete: :delete_all), null: false
    end

    create unique_index(:design_tag_assignments, [:design_id, :tag_id])
    create index(:design_tag_assignments, [:tag_id])

    # 3. Migrate existing categories to tags
    execute """
    INSERT INTO design_tags (name, color, user_id, inserted_at, updated_at)
    SELECT name, color, user_id, inserted_at, updated_at
    FROM design_categories
    """

    # 4. Migrate category assignments to pivot table
    execute """
    INSERT INTO design_tag_assignments (design_id, tag_id)
    SELECT d.id, t.id
    FROM label_designs d
    INNER JOIN design_categories c ON d.category_id = c.id
    INNER JOIN design_tags t ON t.name = c.name AND t.user_id = c.user_id
    """

    # 5. Drop category_id from label_designs
    drop index(:label_designs, [:category_id])
    alter table(:label_designs) do
      remove :category_id
    end

    # 6. Drop design_categories table
    drop table(:design_categories)
  end

  def down do
    # Recreate design_categories table
    create table(:design_categories) do
      add :name, :string, null: false
      add :color, :string, default: "#6366F1"
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:design_categories, [:user_id])
    create unique_index(:design_categories, [:user_id, :name])

    # Re-add category_id to label_designs
    alter table(:label_designs) do
      add :category_id, references(:design_categories, on_delete: :nilify_all)
    end

    create index(:label_designs, [:category_id])

    # Migrate tags back to categories
    execute """
    INSERT INTO design_categories (name, color, user_id, inserted_at, updated_at)
    SELECT name, color, user_id, inserted_at, updated_at
    FROM design_tags
    """

    # Migrate first tag assignment back (can only have one category)
    execute """
    UPDATE label_designs SET category_id = (
      SELECT c.id
      FROM design_tag_assignments dta
      INNER JOIN design_tags t ON dta.tag_id = t.id
      INNER JOIN design_categories c ON c.name = t.name AND c.user_id = t.user_id
      WHERE dta.design_id = label_designs.id
      LIMIT 1
    )
    """

    # Drop tag tables
    drop table(:design_tag_assignments)
    drop table(:design_tags)
  end
end
