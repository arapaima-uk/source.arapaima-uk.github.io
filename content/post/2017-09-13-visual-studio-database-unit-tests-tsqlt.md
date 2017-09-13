+++
title=  'Combining tSQLt mocks with Visual Studio SQL Server Unit Tests'
date =  "2017-09-13"
tags = ["Visual Studio", "tSQLt"]
draft = false
+++

This came up in a question after a recent talk about database unit testing; I've done something similar on a client project in the past, and it was in my "old" talk about testing. So, I thought I'd write it down here in case it's useful to anyone, not least the person who was asking the question.

A `.zip` file of the complete solution can be downloaded from [here](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/tSQlt-VsTest/KebabTestDemo.zip).

For many years, Visual Studio Database Projects - in SSDT as well as in its predecessors - have included an additional template for generating SQL Server Unit Tests. 

## SQL Server Unit Tests

SQL Server Unit Tests live in a SQL Server Unit Test _Class_, which is contained in an ordinary (.NET) Unit Test Project.

There is some additional configuration scoped to the Test _Project_, namely the connection string(s) that will be used to execute the tests, and optionally the name of a database project to deploy before every test run.

The Test Class is an ordinary test class with some boilerplate code supplied as well as a designer for creating SQL Server Unit Tests.

The advantages of using Visual Studio to create our SQL Server Unit Tests are that the ouputs of the test are produced in `.trx` format, which is well understood by many CI tools, not least the ones from Microsoft, and that the tests can be run by the test runner built into Visual Studio.

### The SQL Server Unit Test Designer

The test designer supports up to three Transact SQL scripts per test, called Pre-Test, Test, and Post-Test, which are run in the order you would expect. There is also the option to create class-scoped scripts for Test Initialize and Test Cleanup, which are run before and after every individual test in the class.

![The SQL Server Unit Test Designer](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/tSQlt-VsTest/unitTestDesigner.png)

For each of these scripts, there is the option to add test assertions, which are referred to  "Test Conditions" in this framework. The built-in test conditions are not particularly flexible, but writing custom test conditions is a topic for another day. 

At the time of writing, it is almost exactly ten years since the inventor of NUnit (and of other things) decided that common SetUp and TearDown methods [probably weren't such a good idea after all](http://jamesnewkirk.typepad.com/posts/2007/09/why-you-should-.html), mainly as they make it difficult to see what a test is actually _doing_. 

This is complicated further in SQL Server Unit Tests, as the Pre-Test and Post-Test scripts don't use the same connection as the main Test script, which can lead to even more unexpected results.

So, this example won't make use of the Pre-Test and Post-Test scripts, or of their class-scoped equivalents.

Finally, there is no support for mocks or fakes of any kind in the Visual Studio SQL Server unit testing framework.

Fortunately, there is another testing framework that provides just such support, namely [tSQLt](http://tsqlt.org/).

### tSQLt

In the .NET/Java/whatever worlds, after deciding on a Unit Test Framework to use - NUnit, xUnit, MSTest, etc. - we are still faced with a further decision regarding what mocking framework to use, for instance Moq, NSub, Rhino, the Microsoft one that nobody's heard of because it's only in VS Enterprise, etc. etc.

In the case of tSQLt, the Unit Test framework and the mocking framework are bundled together into a single package.

However, this doesn't mean that these components can't be _used_ in isolation from one another. 

## Crossing the streams

The present example will demonstrate the use of the mocking facilities of tSQLt in conjunction with the test designer and test runner built into Visual Studio.

There are a few ways of getting the tSQLt objects deployed to where they are needed for testing, the way I use most often is basically [this one](https://the.agilesql.club/Blog/Ed-Elliott/AdventureWorksCI-Step5-Adding-tSQLt-Dacpac-To-The-Solution), whereby we create a `.dacpac` of just the tSQLt objects (or use one we made earlier!), and create a second database project with a Database Reference of type "Same Database" to the project we are trying to test, and a reference to our tSQLt `.dacpac`. The `.dacpac` file needs to be somewhere in our source folders, as it will be added by path. We also need a reference to the master database, as this is required to build the tSQLt project. 

![Solution Explorer View showing tsqlt projects](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/tSQlt-VsTest/SolutionExplorerView.png)

In the above illustration, KebabTestDemo is the application we are testing, KebabTestDemo.tSQLt is the database project that contains _only_ the references to our tSQLt dacpac and to master, and KebabTestDemo.Tests is the Unit Test project that contains our SQL Server Unit Test.

In the "SQL Server Test Configuration" dialog, we specify the connection string to use for runnng our tests. This information is stored in the `app.config` for the test assembly, meaning it is scoped to the _project_ rather than to the individual test _classes_.

![The SQL Server Test Configuration dialog](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/tSQlt-VsTest/SQLServerTestConfiguration.png)

This dialog also allows us to specify that we want to deploy a database project at the start of every test run, so that all of our latest changes get included. The keen-eyed will notice, however, that we can only specify _one_ project here, whereas we have _two_ database projects in our solution. Normally I'd just leave this blank and try to remember to deploy my updated project before every test run in Visual Studio, and hope that the CI Server "remembers" to deploy its projects before its own test runs. 

However, there is a solution, outlined in an [MSDN blog post from 2009](https://blogs.msdn.microsoft.com/bahill/2009/07/31/deploying-composite-projects-through-a-database-unit-test-run/) that allows us to take advantage of this "automatic deployment" feature from Visual Studio.

In short, we subclass the `SqlDatabaseTestService` class used in `SqlDatabaseSetup.cs` to allow us to deploy not one, but two projects from the `InitializeAssembly` method. 

{{< highlight csharp  >}}
class KebabDbTestService : SqlDatabaseTestService
{
    public void DeployCompositeProject()
    {
        DeployDatabaseProject(@"..\..\..\KebabTestDemo\KebabTestDemo.sqlproj", "Release", "System.Data.SqlClient", GetConnectionString());
        DeployDatabaseProject(@"..\..\..\KebabTestDemo.tSQLt\KebabTestDemo.tSQLt.sqlproj", "Release", "System.Data.SqlClient", GetConnectionString());

    }

    private static string GetConnectionString()
    {
        var config = (SqlUnitTestingSection) ConfigurationManager.GetSection("SqlUnitTesting");

        return config.ExecutionContext.ConnectionString;
    }
}
{{< / highlight >}}

Note that this pays no attention to the `app.config` setting that tells us what projects to deploy, so caution is advised!

We then call our new code from the `InitializeAssembly` method in `SqlDatabaseSetup`:

{{< highlight csharp>}}
// Setup the test database based on setting in the
// configuration file
//SqlDatabaseTestClass.TestService.DeployDatabaseProject();
//SqlDatabaseTestClass.TestService.GenerateData();

var service = new KebabDbTestService();

service.DeployCompositeProject();

{{< / highlight >}}
(the commented out code is the previous contents of this method)

### Transactions

One of the features of tSQLt is that all the procedures for running unit tests wrap every individual test in a transaction which is rolled back at the end of the test, meaning that the database is in the same state at the end of the test as at the beginning. This is unquestionably a _good thing_, as it means that the tests are all independent of one another, and that we don't need to think about test "teardown" actions.

In the case of Visual Studio unit tests, we need to add this support manually. There are a few ways of doing this [documented on MSDN](https://msdn.microsoft.com/en-US/library/jj851217.aspx), of which I'll consider two.

The first is to insert `BEGIN TRANSACTION` and `ROLLBACK TRANSACTION` at the beginning and end of every test script. Whilst this is effective, you need to remember to do it every time. My preferred method requires [further doctoring of the C# code behind the designer](https://msdn.microsoft.com/en-us/library/jj851217.aspx#Anchor_2) so that every test is wrapped in a [`TransactionScope`](https://msdn.microsoft.com/en-us/library/system.transactions.transactionscope.aspx). The only thing to remember here is that the Distributed Transaction Co-ordinator, better known as MSDTC, must be running on the machine where the test is executed, whether this is on your desktop or on a build server.

The only changes we make are the ones highlighted below; we add a reference to `System.Transactions` and a member variable of type `System.Transactions.TransactionScope`. We then initialise this variable in `TestInitialize()` and call its `Dispose()` method in `TestCleanup()`, which will throw away the transaction without committing it.

{{< highlight csharp "hl_lines=1 8 17 24" >}}
using System.Transactions;

namespace KebabTestDemo.Tests
{
    [TestClass()]
    public class KebabOrderLineTests : SqlDatabaseTestClass
    {
        TransactionScope _t;
        public KebabOrderLineTests()
        {
            InitializeComponent();
        }

        [TestInitialize()]
        public void TestInitialize()
        {
            _t = new TransactionScope();
            base.InitializeTest();
        }
        [TestCleanup()]
        public void TestCleanup()
        {
            base.CleanupTest();
            _t.Dispose();
        }
{{< / highlight >}}

Now when we run our tests, each individual test will be wrapped in a transaction, which will be disposed of (i.e. rolled back) at the end of the test.

### The Test Script

The test script now consists of only three lines; [faking the table](http://tsqlt.org/user-guide/isolating-dependencies/faketable/) used in the test, calling the procedure, and selecting the results.

![The completed Visual Studio Unit Test with tSQLt Mocks](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/tSQlt-VsTest/VSUnitTestWithTsqltMocks.png)

The results will be processed by the "Test Condition" at the bottom of the picture, this is a "Data Checksum" condition, which is the only way to validate a multi-column, multi-row result using the built-in test conditions.

The checksum is configured using the following dialog; we have to select a database connection to use (in this case, it doesn't really matter what that connection is), followed by a query that will return the same result set (including column names) as we expect the result set of the test to return. We then click "Retrieve" to execute the query, retrieve the results, and populate the checksum value (in this case `-1371852473`, visible in the screenshot above)

![The Data Checksum Test Configuration Dialog](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/tSQlt-VsTest/DataChecksumConfiguration.png)

## Running the Test

Having got to here, we are ready to run our test from the Visual Studio Test Explorer. This will re-deploy our project(s) and run the test, wrapped in a `TransactionScope`.

![ScreenShot of passing test](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/tSQlt-VsTest/PassingTest.png)


## Conclusion

This is a bit fiddly to set up, and even more fiddly to set up on a CI Server. However if you have some reason why you want or need to use the built-in testing facilities in Visual Studio, then hopefully this article has demonstrated a way to take advantage of the tSQLt mocking framework.

If you [download the sample project](https://s3-eu-west-1.amazonaws.com/aksidjenakfjg/tSQlt-VsTest/KebabTestDemo.zip), then the test should build and run the first time, once you set the connection string in the "SQL Server Test Configuration" dialog.

