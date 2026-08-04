using SqlPerf.Api.Models;
using SqlPerf.Api.Services;
using Xunit;

namespace SqlPerf.Api.Tests;

public class DesignEvaluatorTests
{
    // Builds a schema with one table and the named columns. Everything the rule
    // does not look at is given a harmless default, so a test reads as the one
    // fact it is about.
    private static SchemaDto SchemaWith(string table, params string[] columns) =>
        new("dbo", true, new List<SchemaTableDto>
        {
            new(table, 0,
                columns.Select(c => new SchemaColumnDto(c, "int", true, false, false, null)).ToList(),
                new List<SchemaIndexDto>(),
                new List<SchemaForeignKeyDto>(),
                false,
                new List<SchemaCheckDto>())
        });

    private static RuleSpec Absent(string table, string column) =>
        new() { Type = "columnAbsent", Table = table, Column = column };

    [Fact]
    public void ColumnAbsent_passes_when_the_column_was_moved_out()
    {
        var schema = SchemaWith("Enrolment", "StudentId", "CourseCode");

        var result = DesignEvaluator.Evaluate(new[] { Absent("Enrolment", "CourseTitle") }, schema);

        Assert.True(result.Passed);
    }

    [Fact]
    public void ColumnAbsent_fails_when_the_redundant_column_is_still_there()
    {
        var schema = SchemaWith("Enrolment", "StudentId", "CourseCode", "CourseTitle");

        var result = DesignEvaluator.Evaluate(new[] { Absent("Enrolment", "CourseTitle") }, schema);

        Assert.False(result.Passed);
    }

    [Fact]
    public void ColumnAbsent_is_case_insensitive_like_SQL_Server()
    {
        var schema = SchemaWith("Enrolment", "coursetitle");

        var result = DesignEvaluator.Evaluate(new[] { Absent("Enrolment", "CourseTitle") }, schema);

        Assert.False(result.Passed);
    }

    // The load-bearing case. Deleting the table must not be a way to pass a
    // rule that asks for a column to have been moved out of it.
    [Fact]
    public void ColumnAbsent_fails_when_the_table_itself_is_missing()
    {
        var schema = SchemaWith("SomethingElse", "StudentId");

        var result = DesignEvaluator.Evaluate(new[] { Absent("Enrolment", "CourseTitle") }, schema);

        Assert.False(result.Passed);
        Assert.Contains("no table", result.Conditions[0].Detail);
    }
}
