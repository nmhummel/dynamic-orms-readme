require_relative "../config/environment.rb"
require 'active_support/inflector'

class Song

  # grabs us the table name we want to query for column names
  def self.table_name
    self.to_s.downcase.pluralize 
  end
  # takes the name of the class (self), turns it into a string with #to_s, 
  # downcases (or "un-capitalizes") that string and then "pluralizes" it, or makes it plural.
  # pluralize method is provided to us by the active_support/inflector code library

  # grabs us those column names (as an array)
  def self.column_names
    DB[:conn].results_as_hash = true
    # will return to us (thanks to our handy #results_as_hash method) an array of hashes describing the table itself.
    # Each hash will contain information about one column.
    sql = "pragma table_info('#{table_name}')" # accesses the name of the table we are querying
    table_info = DB[:conn].execute(sql)
    column_names = [] # empty array for storage
    table_info.each do |row| # iterate over the resulting array of hashes 
      column_names << row["name"] # to collect just the name of each column and shovels it into empty array
    end
    column_names.compact # to be safe and get rid of any nil values that may end up in our collection.
  end

  # tell our Song class that it should have an attr_accessor named after each column
  self.column_names.each do |col_name| 
    # iterate over the column names stored in the column_names class method and set an attr_accessor for each one
    attr_accessor col_name.to_sym # convert the column name string into a symbol with the #to_sym (:)
  end
  # This is metaprogramming because we are writing code that writes code for us. 
  # By setting the attr_accessors in this way, a reader and writer method for each column name is dynamically created, 
  # without us ever having to explicitly name each of these methods.

  # build an abstract initialize method using metaprogramming
  # takes in hash of named (keyword) arguments w/o explicitly naming them
  def initialize(options={})  #  take in an argument of options, which defaults to an empty hash
  # We expect #new to be called with a hash, so when we refer to options inside the #initialize method, we expect to be operating on a hash.
    options.each do |property, value| # iterate over the options hash and... 
      self.send("#{property}=", value) # use .send method to interpolate the name of each hash key as a method that we set equal to that key's value.
    end
    # As long as each property has a corresponding attr_accessor, this #initialize method will work.
  end

  # The conventional #save is an instance method, so inside a #save method, self will refer to the instance of the class, not the class itself
    def save
    sql = "INSERT INTO #{table_name_for_insert} (#{col_names_for_insert}) VALUES (#{values_for_insert})"
    DB[:conn].execute(sql)
    @id = DB[:conn].execute("SELECT last_insert_rowid() FROM #{table_name_for_insert}")[0][0]
  end
  
  # In order to use a class method inside an instance method, we need to do the following:
  def table_name_for_insert  # def some_instance_method
    self.class.table_name  # self.class.some_class_method - to access the table name we want to INSERT into from inside our #save method
  end

    # grabs the column names of the table associated with a given class
  def col_names_for_insert # grab our column names in an abstract manner
      # When we INSERT a row into a database table for the first time, we don't INSERT the id attribute. In fact, our Ruby object has an id of nil before it is inserted into the table. 
      # The magic of our SQL database handles the creation of an ID for a given table row and then we will use that ID to assign a value to the original object's id attribute.
    self.class.column_names.delete_if {|col| col == "id"}.join(", ") 
     # So, when we save our Ruby object, we should not include the id column name or insert a value for the id column. 
     # Therefore, we need to remove "id" from the array of column names returned.
     # Results are in an array, so turn them into a comma separated list, contained in a string
  end
  # Now we have all the code we need to grab a comma separated list of the column names of the table associated with any given class.

  # an abstract way to grab the values we want to insert.
  # When inserting a row into our table, we grab the values to insert by grabbing the values of that instance's attr_reader's
  # We already know that the names of that attr_accessor methods were derived from the column names of the table associated to our class. Those column names are stored in the #column_names class method.
  def values_for_insert # ex. INSERT INTO songs (name, album) VALUES ("name", "album") --> array
    values = [] # empty array for storage
    # Let's iterate over the column names stored in #column_names and...
    self.class.column_names.each do |col_name|  
      # use the #send method with each individual column name to invoke the method by that same name and capture the return value:
      values << "'#{send(col_name)}'" unless send(col_name).nil? # push the return value of invoking a method via the #send method
      #  unless that value is nil (as it would be for the id method before a record is saved, for instance).
    end
    # results in a values array
    values.join(", ")  # join array into a string
  end
  # Notice that we are wrapping the return value in a string. That is because we are trying to craft a string of SQL. Also notice that each individual value will be enclosed in single quotes, ' ', inside that string. 
  # That is because the final SQL string will need to look like this:
    # INSERT INTO songs (name, album)
    # VALUES 'Hello', '25'; 
  
  def self.find_by_name(name)
    sql = "SELECT * FROM #{self.table_name} WHERE name = '#{name}'"
    DB[:conn].execute(sql)
  end
  # Note: Using String interpolation for a SQL query creates a SQL injection vulnerability, which we've previously stated is a bad idea as it creates a security issue, however, we're using these examples to illustrate how dynamic ORMs work.
  # This method is dynamic and abstract because it does not reference the table name explicitly. Instead it uses the #table_name class method we built that will return the table name associated with any given class.
end



