using api.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace api.Migrations;

/// <inheritdoc />
[DbContext(typeof(AppDbContext))]
[Migration("20260406230000_PartnerAssignmentNullableSafehouse")]
public partial class PartnerAssignmentNullableSafehouse : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AlterColumn<int>(
            name: "safehouse_id",
            table: "partner_assignments",
            type: "int",
            nullable: true,
            oldClrType: typeof(int),
            oldType: "int",
            oldNullable: false);
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(
            "UPDATE dbo.partner_assignments SET safehouse_id = 1 WHERE safehouse_id IS NULL;");

        migrationBuilder.AlterColumn<int>(
            name: "safehouse_id",
            table: "partner_assignments",
            type: "int",
            nullable: false,
            oldClrType: typeof(int),
            oldType: "int",
            oldNullable: true);
    }
}
