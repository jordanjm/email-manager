#! /usr/bin/perl
################################################################################
#
#    Email Manager
#    
#    This program manages a email system database.  It is designed to manage 
#    an email server set up using the following tutorial:
#
#    https://www.linode.com/docs/email/postfix/email-with-postfix-dovecot-and-
#    mariadb-on-centos-7
#
#    Copyright (C) Jordan McGilvray
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
################################################################################

use strict;
use warnings;
use 5.010;
use DBI;
use Term::ANSIColor;
use Term::ReadKey;

#Waits for a key press
#Input: Any Key
#Output: Displays the main menu
#Returns: None
#DB Queries: None
sub waitForIt
{
        print (colored( "\nPress Any Key to Continue\n", 'green'));
        ReadMode('cbreak');
        my $waitForIt = ReadKey(0);
        ReadMode('normal');
        &mainMenu();
}

#Database Connection Info
#Input: Contents of the .connect file
#Returns: Array of Database Connection Info
#Output: Possible Error if the .connect file cannot be opened
#The .connect file needs to be 4 lines long. It has 1 value on each line.
#database name
#database user
#password
sub dbInfo
{
	open FILE, ".connect" or die $!;
	my @dbConnect = <FILE>;
	close(FILE);
	chomp @dbConnect;
	return @dbConnect;
}

#getDBtable gets the values in a database table and returns them
#Input: Variables: Database Name, Database User, Database User Password
#Returns: Array of Arrays containing the information
#Output: None
sub getDBtable
{
	#Declare Variables
	my @dbConnect = @_;
	my @tableContent;
	my $arrayX = 0;
	my $arrayY = 0;
	#Database Connection
	my $dbh = DBI->connect("DBI:mysql:$dbConnect[0]", "$dbConnect[1]", "$dbConnect[2]"                                                                                                                                         ) || die "Could Not Connect to Database: $DBI::errstr";
	#Define the query to get the contents of the Database
	my $sql = qq{ SELECT * FROM $dbConnect[3] };
	#Prepare and Execute the query
	my $sth = $dbh->prepare( $sql );
	$sth->execute();
	#Get the Table Headers
	my $columnHeaders = $sth->{NAME};
	#Place the contents into the Array of Arrays
	while (my @row = $sth->fetchrow_array()) 
	{
		my $rowLength = scalar(@row);
		$arrayY = 0;
		foreach (@row)
		{
			$tableContent[$arrayX][$arrayY] = $_;
			$arrayY++;
		}
		$arrayX++;
	}
	#Finish with the query
	$sth->finish();
	#Disconnect from the database
	$dbh->disconnect();
	#Add Headers to the return array
	unshift @tableContent, $columnHeaders;
	#Return Table Content
	return @tableContent;
}

#Formats and Displays the content of a Database Table
#Input: Array of Arrays Containing the table
#Returns: None
#Output: Formatted Database Table
sub displayDBtable
{
	system("clear");
	#Get the Database Table Content
	my @tableContent = @_;
	#Get the Table Name and Capitalize it
	my $TableName = uc(shift(@tableContent));
	#Display the formatted Table
	print (colored( sprintf("%-40s","$TableName"),'yellow' ),"\n==========\n");
	my $arrayCounter = 0;
	foreach (@tableContent)
	{
		if ($arrayCounter == 0)
		{
			foreach (@$_)
			{
				my $text = ucfirst($_);
				print (colored( sprintf("%-40s","$text"),'cyan' ));
			}
		}
		else
		{
			foreach (@$_)
			{
				printf "%-40s","$_";
			}
		}
		$arrayCounter++;
		print "\n";
	}
	print "==========\n";
	#Varient of the waitForIt subroutine.  Returns to the Display menu
	print (colored( "\nPress Any Key to Continue\n", 'green'));
	ReadMode('cbreak');	
	my $waitForIt = ReadKey(0);
	ReadMode('normal');
	displayTable();
}

#Add a new entry to a Database Table
#I used given/when because there can only be 3 options via the menu.  I thought of making each of these its own subroutine, but I like keeping the functionality together. 
#Input: Values for the new entry
#Returns: None
#Output: None
#DB QUERIES:
#	Domains: INSERT INTO domains (domain) VALUES("$newDomain")
#	Email Account: INSERT INTO users (email, password) VALUES("$newEmailAddress", ENCRYPT("$newEmailPassword"))
#	Forwarders: INSERT INTO forwardings VALUES("$newEmailAddress", "$newForwardToAddress")
sub addToTable
{
	my @dbConnect = dbInfo();
	my $tableName = @_[0];
	my $newVal1='';
	my $newVal2='';
	my $sql;
	my @dbTable = getDBtable(@dbConnect, $tableName); 
	my $columnName = shift @dbTable;
	my $columnCount = scalar @$columnName;
	#Take in the first (or only) value for adding entries to the database
	print (colored("Enter the New ".ucfirst(@$columnName[0])." to Add.\n#", 'cyan'));
	chomp($newVal1 = <STDIN>);
	#If there is a second column (Password or actual email account, depending on if it is a forwarder or email account
	if ($columnCount == 2)
	{
		print (colored("Enter the New ".ucfirst(@$columnName[1])." to Add.\n#", 'cyan'));
		chomp($newVal2 = <STDIN>);
	}
	#Connect to the database
	my $dbh = DBI->connect("DBI:mysql:$dbConnect[0]", "$dbConnect[1]", "$dbConnect[2]"                                                                                                                                         ) || die "Could Not Connect to Database: $DBI::errstr\n";
	#Determine which query to run
	given ( $tableName )
	{
		when("domains")		
		{
                	$sql = qq{ INSERT INTO $tableName (@$columnName[0]) VALUES ("$newVal1") };
			break; 
		}
		when("users")
		{
                	$sql = qq{ INSERT INTO $tableName VALUES("$newVal1", ENCRYPT("$newVal2")) };
			break; 
		}
		when("forwardings")
		{ 
                	$sql = qq{ INSERT INTO $tableName VALUES("$newVal1", "$newVal2")  };
			break; 
		}
	}
	#Close Prepare, execute, and finish the query.  Then disconnect from the database
	my $sth = $dbh->prepare( $sql );
	$sth->execute();
	$sth->finish();
	$dbh->disconnect();
	#Wait for a keypress before continuing. 
	waitForIt();
}

#Delete an entry to a Database Table
#Input: Entry to delete
#Returns: None
#Output: None
#DB Query: DELETE FROM $tableName WHERE $columnName = "$databaseRows{$inputItem}" limit 1 
sub removeFromTable
{
	my $tableName = $_[0];
	#Get the Database Connection Information
	my @dbConnect = dbInfo(); 
	#Get the Database Table Content
	my @dbTable = getDBtable(@dbConnect,$tableName);
	my $rowCounter = 1;
	my %databaseRows;
	my $inputItem = 0;
	my $key;
	my $value;
	#Retrieve the main column name
	my $columnName = shift @dbTable;
	$columnName = "@$columnName[0]";
	#Create a menu of items that can be  deleted
	foreach (@dbTable)
	{
		$databaseRows{"$rowCounter"} = "@$_[0]";
		$rowCounter++;
	}
	#This is where the database is sorted.  It is not a numerical sort.  So 10 follows 1.
	foreach $key(sort keys %databaseRows)
	{
		print "$key. $databaseRows{$key}\n";
	}
	print "$rowCounter. Return to the Main Menu\n";
        print (colored("Which Entry Would You Like To Delete?\nType the number next to the entry.\n#", 'cyan'));
	#I limit input to the values of the menu
	while (($inputItem > $rowCounter) || ($inputItem < 1))
	{
		chomp($inputItem = <STDIN>);
	}
	#Exit back to main menu if a deletion is not needed.
	if ($inputItem eq $rowCounter)
	{
		&mainMenu ();
	}
	#Connect to the Database
        my $dbh = DBI->connect("DBI:mysql:$dbConnect[0]", "$dbConnect[1]", "$dbConnect[2]"                                                                                                                                         ) || die "Could Not Connect to Database: $DBI::errstr";
	#Create the query to delete the row
        my $sql = qq{ DELETE FROM $tableName WHERE $columnName = "$databaseRows{$inputItem}" limit 1 };
	#Prepare and execute the query
        my $sth = $dbh->prepare( $sql );
        $sth->execute();
        #Finish with the query
        $sth->finish();
        #Disconnect from the database
        $dbh->disconnect();
	#Wait for a keypress and return to the main menu
	waitForIt();
}

#Edits entry to a Database Table
#Input: entry to edit, and new values
#Returns: None
#Output: None
#DBQueries: 
sub editTable
{
	my @dbConnect = dbInfo();
	my $tableName = $_[0];
	my $rowCounter = 1;
	my $columnCount = 1;
	my $newCol1Value;
	my $newCol2Value;
	my $tableHeader;
	my $key=0;
	my $inputItem=0;
	my @newColVals;
	my @tableHeaders;
	my @dbTable = getDBtable(@dbConnect,$tableName);
	my %dbRows;
	#Get the Table Headers
	$tableHeader = shift @dbTable;
	foreach (@$tableHeader)
	{
		push (@tableHeaders,$_);
	}
	#Get the number of columns for the upcoming MySQL query
	$columnCount = scalar @tableHeaders;
	#Display Database Table
	foreach (@dbTable)
	{
                $dbRows{"$rowCounter"} = "@$_[0]";
		$rowCounter++;
	}
        #This is where the database is sorted.  It is not a numerical sort.
        foreach $key(sort keys %dbRows)
        {
        	print "$key. $dbRows{$key}\n";
        }
        print "$rowCounter. Return to the Main Menu\n";
        print (colored("Which Entry Would You Like To Edit?\nType the number next to the entry.\n#", 'cyan'));
        #I limit input to the values of the menu
        while (($inputItem > $rowCounter) || ($inputItem < 1))
        {
		print "\n$inputItem, $rowCounter, Stuck in the Input Selection Loop\n";
        	chomp($inputItem = <STDIN>);
        }
        #Exit back to main menu if a deletion is not needed.
        if ($inputItem eq $rowCounter)
        {
        	&mainMenu ();
        }
	#Database Query Selector
	#UPDATE $tableName SET $tableHeaders[0]=new-$newInput, $tableHeaders[1]=new-$newInput1 WHERE $tableHeaders[0]=$dbRows{$inputItem}
	print "$columnCount\n";
	for(my $i=0; $i < $columnCount; $i++)
	{
		print (colored("Please enter a value for $tableHeaders[$i]\n#",'cyan'));
		chomp ($newColVals[$i] = <STDIN>);
	}
        my $dbh = DBI->connect("DBI:mysql:$dbConnect[0]", "$dbConnect[1]", "$dbConnect[2]"                                                                                                                                         ) || die "Could Not Connect to Database: $DBI::errstr";
        #Create the query to delete the row
        my $sql;
        #Prepare and execute the query
	given ( $columnCount )
	{
		when(1)
		{
			$sql = qq{ UPDATE $tableName SET $tableHeaders[0]="$newColVals[0]" WHERE $tableHeaders[0]="$dbRows{$inputItem}" };
			print qq{ UPDATE $tableName SET $tableHeaders[0]="$newColVals[0]" WHERE $tableHeaders[0]="$dbRows{$inputItem}" };
			break;
		}
		when(2)
		{
			$sql = qq{ UPDATE $tableName SET $tableHeaders[0]="$newColVals[0]",$tableHeaders[1]="$newColVals[1]" WHERE $tableHeaders[0]="$dbRows{$inputItem}" };
			break;
		}
	}
	my $sth = $dbh->prepare( $sql );
	$sth->execute();
	$sth->finish();
	$dbh->disconnect();
	waitForIt();
}

#Select Database Table to Display
#Input: None
#Returns: None
#Output: Display Tables Menu
sub displayTable
{
	system("clear");
        print (colored( "  _____  _           _               _______    _     _           \n", 'cyan'));
        print (colored( " |  __ \\(_)         | |             |__   __|  | |   | |          \n", 'cyan'));
        print (colored( " | |  | |_ ___ _ __ | | __ _ _   _     | | __ _| |__ | | ___  ___ \n", 'cyan'));
        print (colored( " | |  | | / __| '_ \\| |/ _` | | | |    | |/ _` | '_ \\| |/ _ \\/ __|\n", 'cyan'));
        print (colored( " | |__| | \\__ \\ |_) | | (_| | |_| |    | | (_| | |_) | |  __/\\__ \\\n", 'cyan'));
        print (colored( " |_____/|_|___/ .__/|_|\\__,_|\\__, |    |_|\\__,_|_.__/|_|\\___||___/\n", 'cyan'));
        print (colored( "              | |             __/ |                               \n", 'cyan'));
        print (colored( "              |_|            |___/                                \n", 'cyan'));
        print (colored( sprintf("    %-5s","1. View Domain Table"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","2. View Email Account Table"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","3. View Forwarder Table"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","4. Return to the Main Menu"),'yellow' ),"\n");
	my $choice = -1;
	my $warningCounter = 0;
	while (1)
	{
		print (colored( "Please Enter Your Selection\n", 'red'));
                print (colored("#", 'cyan'));
		while (($choice gt 4) || ($choice lt 1))
		{
			if ($warningCounter ne 0)
			{
				print "Please enter a valid choice.\n";
			}
			$warningCounter++;
                	chomp($choice = <STDIN>);
		}
                given ($choice)
                {
                	when(1)         { displayDBtable("Domains",getDBtable(dbInfo(),"domains")); break; } #View Domain Table
                        when(2)         { displayDBtable("Email Accounts",getDBtable(dbInfo(),"users")); break; } #View Email Account Table
                        when(3)         { displayDBtable("Forwarders",getDBtable(dbInfo(),"forwardings")); break; } #View Forwarder Table
			when(4)		{ &mainMenu(); break; } #Return to the Main Menu
                }
	}
}

#Display Domain Table Editing Menu
#Input: None
#Returns: None
#Output: Domain Editing Menu
sub editDomains
{
	system("clear");
        print (colored( "██████╗  ██████╗ ███╗   ███╗ █████╗ ██╗███╗   ██╗███████╗\n", 'cyan'));
        print (colored( "██╔══██╗██╔═══██╗████╗ ████║██╔══██╗██║████╗  ██║██╔════╝\n", 'cyan'));
        print (colored( "██║  ██║██║   ██║██╔████╔██║███████║██║██╔██╗ ██║███████╗\n", 'cyan'));
        print (colored( "██║  ██║██║   ██║██║╚██╔╝██║██╔══██║██║██║╚██╗██║╚════██║\n", 'cyan'));
        print (colored( "██████╔╝╚██████╔╝██║ ╚═╝ ██║██║  ██║██║██║ ╚████║███████║\n", 'cyan'));
        print (colored( "╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝\n", 'cyan'));
        print "Please Select the number of the option you wish\n";
        print (colored( sprintf("    %-5s","1. Add a Domain"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","2. Delete a Domain"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","3. Edit a Domain"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","4. Return to the Main Menu"),'yellow' ),"\n");
        my $choice = -1;
	my $warningCounter = 0;
        while (1)
        {
                print (colored( "Please Enter Your Selection\n", 'red'));
                print (colored("#", 'cyan'));
                while (($choice gt 4) || ($choice lt 1))
                {
                        if ($warningCounter ne 0)
                        {
                                print "Please enter a valid choice.\n";
                        }
			$warningCounter++;
                        chomp($choice = <STDIN>);
                }
                given ($choice)
                {
                	when(1)         { addToTable("domains"); break; } #Add a Domain
                        when(2)         { removeFromTable("domains"); break; } #Delete a Domain
                        when(3)         { editTable("domains"); break; } #Edit a Domain
                        when(4)         { mainMenu(); break; } #Return to the Main Menu
                }
        }
}

#Displays the Email editing menu
#Input: None
#Returns: None
#Output: Email Editing Menu
sub editEmail
{
	system("clear");
        print (colored( "▓█████  ███▄ ▄███▓ ▄▄▄       ██▓ ██▓    \n", 'cyan'));
        print (colored( "▓█   ▀ ▓██▒▀█▀ ██▒▒████▄    ▓██▒▓██▒    \n", 'cyan'));
        print (colored( "▒███   ▓██    ▓██░▒██  ▀█▄  ▒██▒▒██░    \n", 'cyan'));
        print (colored( "▒▓█  ▄ ▒██    ▒██ ░██▄▄▄▄██ ░██░▒██░    \n", 'cyan'));
        print (colored( "░▒████▒▒██▒   ░██▒ ▓█   ▓██▒░██░░██████▒\n", 'cyan'));
        print (colored( "░░ ▒░ ░░ ▒░   ░  ░ ▒▒   ▓▒█░░▓  ░ ▒░▓  ░\n", 'cyan'));
        print (colored( " ░ ░  ░░  ░      ░  ▒   ▒▒ ░ ▒ ░░ ░ ▒  ░\n", 'cyan'));
        print (colored( "   ░   ░      ░     ░   ▒    ▒ ░  ░ ░   \n", 'cyan'));
        print (colored( "   ░  ░       ░         ░  ░ ░      ░  ░\n", 'cyan'));
        print "Please Select the number of the option you wish\n";
        print (colored( sprintf("    %-5s","1. Add an Email Account"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","2. Delete an Email Account"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","3. Edit an Email Account"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","4. Return to the Main Menu"),'yellow' ),"\n");
        my $choice = -1;
	my $warningCounter = 0;
        while (1)
        {
                print (colored( "Please Enter Your Selection\n", 'red'));
                print (colored("#", 'cyan'));
                while (($choice gt 4) || ($choice lt 1))
                {
                        if ($warningCounter ne 0)
                        {
                                print "Please enter a valid choice.\n";
                        }
			$warningCounter++;
                        chomp($choice = <STDIN>);
                }
                given ($choice)
                {
                	when(1)         { addToTable("users"); break; } #Add a Domain
                        when(2)         { removeFromTable("users");  break; } #Delete a Domain
                        when(3)         { editTable("users"); break; } #Edit a Domain
                        when(4)         { mainMenu(); break; } #Return to the Main Menu
		}
        }
}

#Displays the forwarders editing menu
#Input: None
#Returns: None
#Output: Forwarders Editing Menu
sub editForwarders
{
	system("clear");
        print (colored( "____ ____ ____ _ _ _ ____ ____ ___  ____ ____ ____ \n", 'cyan'));
        print (colored( "|___ |  | |__/ | | | |__| |__/ |  \\ |___ |__/ [__  \n", 'cyan'));
        print (colored( "|    |__| |  \\ |_|_| |  | |  \\ |__/ |___ |  \\ ___] \n", 'cyan'));
        print "Please Select the number of the option you wish\n";
        print (colored( sprintf("    %-5s","1. Add a Forwarder"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","2. Delete a Forwarder"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","3. Edit a Forwarder"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","4. Return to the Main Menu"),'yellow' ),"\n");
        my $choice = -1;
	my $warningCounter = 0;
        while (1)
        {
                print (colored( "Please Enter Your Selection\n", 'red'));
                print (colored("#", 'cyan'));
		while (($choice gt 4) || ($choice lt 1))
		{
			if ($warningCounter > 0)
			{	
                                print "Please enter a valid choice.\n";
			}
			$warningCounter++;
			chomp($choice = <STDIN>);	
		}
                given ($choice)
                {
                	when(1)         { addToTable("forwardings"); break; } #Add a Domain
                        when(2)         { removeFromTable("forwardings"); break; } #Delete a Domain
                        when(3)         { editTable("forwardings"); break; } #Edit a Domain
                        when(4)         { mainMenu(); break; } #Return to the Main Menu
                }
        }
}

#Main Menu of program
#Input: None
#Returns: None
#Output: Main Menu
sub mainMenu
{
	system("clear");
        print (colored( "• ▌ ▄ ·.  ▄▄▄· ▪   ▐ ▄     • ▌ ▄ ·. ▄▄▄ . ▐ ▄ ▄• ▄▌\n", 'cyan'));
        print (colored( "·██ ▐███▪▐█ ▀█ ██ •█▌▐█    ·██ ▐███▪▀▄.▀·•█▌▐██▪██▌\n", 'cyan'));
        print (colored( "▐█ ▌▐▌▐█·▄█▀▀█ ▐█·▐█▐▐▌    ▐█ ▌▐▌▐█·▐▀▀▪▄▐█▐▐▌█▌▐█▌\n", 'cyan'));
        print (colored( "██ ██▌▐█▌▐█ ▪▐▌▐█▌██▐█▌    ██ ██▌▐█▌▐█▄▄▌██▐█▌▐█▄█▌\n", 'cyan'));
        print (colored( "▀▀  █▪▀▀▀ ▀  ▀ ▀▀▀▀▀ █▪    ▀▀  █▪▀▀▀ ▀▀▀ ▀▀ █▪ ▀▀▀ \n", 'cyan'));
	print "Please Select the number of the option you wish\n";
        print (colored( sprintf("    %-5s","1. View Tables"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","2. Add, Delete, & Edit Domains"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","3. Add, Delete, & Edit  Email Accounts"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","4. Add, Delete, & Edit  Forwarders"),'yellow' ),"\n");
        print (colored( sprintf("    %-5s","5. Quit"),'yellow' ),"\n");
	my $choice = -1;
	my $warningFlag = 0;
	while (1)
	{
		print (colored( "Please Enter Your Selection\n", 'red'));
		print (colored("#", 'cyan'));
		while (($choice gt 5) || ($choice lt 1))
		{
			if ($warningFlag >0)
			{
                                print "Please enter a valid choice.\n";
			}
			$warningFlag++;
			chomp($choice = <STDIN>);
		}
		given ($choice)
		{
			when(1)		{ displayTable(); break; } #View Tables
			when(2)		{ editDomains(); break; } #Add and Delete Domains
			when(3)		{ editEmail(); break; } #Add and Delete Email Accounts
			when(4)		{ editForwarders(); break; } #Add and Delete Forwarders
			when(5)		{ print "Goodbye\n"; exit; } #Quit
		}
	}
}

mainMenu() || die;
