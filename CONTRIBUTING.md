# Contribute

Some basic programming knowledge is required, I mean you should be familiar with Lua programming and basic concepts about memory, pointers, dereference and basic C types (char[], (u)int32, float etc.)

If the above is true for you, then:

## How to start?

1. First of all, you should read the notes provided by `Cpecific` [here](https://github.com/Cpecific/twwh2-memreader) and [here](https://github.com/Cpecific/twwh2-memreader/tree/main/struct).

2. Then you will need to spend some time reading the source code of this utility, specificly:
    * `script/db_reader/utils.lua: get_db_address()`
    * `script/db_reader/extractors/tables/*` (at least a few of them)


And if you finally find that you are not afraid of all of the above, then you are ready to start diving deeper into the topic: 

1. install `CheatEngine` and `ReClass.net`

2. (optional) watch some videos or read some articles about using CheatEngine and ReClass.net if you are not familiar with these utilities.
    * I can recommend this YouTube video which I used myself:
        * ReClass.net: [How To Reverse Structures](https://www.youtube.com/watch?v=vQb21RM9-5M)

3. start the game and open the `data/.db_reader_cache.lua` file (which is created after successful initialization of `DBReader`) - there in the first line you can find the current database address in the game memory (it changes after each restart)

4. go to the game db address in the `ReClass.net` window and look at the common structures and how they are used

5. (optional) import `ReClass.net` projects from me and / or from `Cpecific` to see what structures we were able to determine in the course of our own study. This will help you quickly become familiar with the basic structures



## Writing your own table extractor

0. open desired table in RPFM for reference

1. after the successful game start and initialization of `DBReader`, a `data/.db_reader_cache.lua` is created, in which you can find the address of the table you are interested in (search in by the name of the table)

2. go to the table address in the `ReClass.net` window: something like a table header is located in a bidirectional list, it may contain an ID field (`char[16]`) (if it was present in the table) and the position of the table record "tail" (`uint32`) in the array of records. Go to the desired array element and see what is stored in it. Some data may be there in raw form, some in the form of pointers to other related in-game objects. Be prepared to spend some time following the pointers as there can be many

    > for example, if there was a `unit` key in the table, then the array element will most likely contain a pointer to the unit's in-game object from which you can take its key to restore the table to its original form 

    > to make it easier, you can mark up encountered structures in the `ReClass.net` window, so that at some point of time you will have your own collection of known structures, which can speed up your future research

3. when you understand how you can get all the necessary data to restore the table in its original form - it's time to write code! (you can use my own as a reference)
    * I recommend use a [mod for execution of external lua files in game](https://steamcommunity.com/sharedfiles/filedetails/?id=2791573994) for testing purposes

4. once you decide you've finished your extractor and it can produce consistent results, it's time to start integrating it into `DBReader`:

    1. register it with `DBReader:register_table_extractor()` described in the API section (in `README.md`) inside a listener callback function for the `DBReaderCreated` event and request your table with `DBReader:request_table()`

    2. launch the game and check if your table data is available. If not, then look at what is written in `log__db_reader.txt` in the game root folder to clarify what exactly happened.
        > The data returned by extractors is carefully checked for valid format, so be sure to follow the definitions described in `db_reader/types.lua`. You can also read the source code of validators in `db_reader/validators.lua` to learn more about what they do.

        > If you can't figure out why something is going wrong feel free to message me on Discord.

5. if you are finally done with the extractor then:
    1. fork this repository
    2. add your extractor under the `db_reader/extractors/tables` folder with a name by a format `<your_table_name>.lua` to your fork
        * make sure your module return table in the right format (look at other extractors nearby)
        * check that DBReader works fine (you can access your table data) 
    4. create a pull request to this repository
    5. (optional) tag or message me on Discord

---

## Finding static pointer path to DB

> I have left the following instructions for myself in the future, but you may find them useful

At some point in time (perhaps with one of the updates) the current static path of pointers to the database will become invalid. Prepare to spend a lot of time figuring out what has changed. Pray to the gods that CA doesn't change the game's internals too much!

The only way I can help you right now is to make a guide based on my current experience on how to find the static pointer path.

What is the plan:
1. Find a first address of DB and generate pointermap with CheatEngine
2. Find a second address of DB
3. Perform pointer scan with those two addresses with usage of created pointermap
4. Get a shorter valid pointer path that will be static within game restarts and in different modes (at least in `frontend` and `campaign`)
5. Implement it in code
6. Make sure everything works as it should
7. Done -> You are amazing! Really :)


### Finding DB address:

This is the hardest part. You probably need to be creative during this research.

The main idea behind current method is that the db somehow persists in the game's memory even after all internal game objects have been created. This may change in the future, please be aware!

But if the db still exists, then we can find it somehow by looking for its values in memory. The easiest way to implement this idea is to choose a small table with string values, find those values, and go up the pointer path to the table header object in db space, and then get the address of the db itself.

So, let's start:
1. First of all, follow the advice of `Cpecific`, which he left in the comments of his `memreader` mod on the Steam Workshop page: search for the string `wh_event_category_conquest` with CheatEngine (you will probably find 2 or 3 pointers to it in memory)

2. In general it should be a part of string structure that `Cpecific` described in his repository, so search for pointers to this address in memory again.

3. Look at the memory space near this pointer with `ReClass.net`:

    * if it contains two preceding integers ([u]int32) and at least one of them is equal to the number of characters in this string, then you are on the right way - this is definitely a string structure. Then you can move on!

    * if not, well, idk what could change in your future, but try to look for other addresses for this string

3. Find pointers to this string structure. There can be many of them, just every time you get into a new space, try to understand what kind of structure it is:
    
    > Many game objects have a special pointer in memory at the beginning of the object structure. `ReClass.net` displays these pointers as referring to something like `<DATA>Warhammer3.exe.XXXXXXXX`. You must use the address of this pointer if you want to find the correct references to this object in memory. Keep this fact in mind - it will save you time in your research.

    * if it's a space where there are a lot of tightly packed pointers, then you're probably somewhere inside an array -> go to the first element of the array and look for pointers to it

    * if there are two pointers to HEAP inside the current object - check if it is a linked list node
        
        * if so, then try to find pointers to that node (usually there is an array somewhere containing pointers to all the nodes at once, providing access by index) or, if you can't find the pointers, try to find the beginning or end of this list. But it could cost you a lot of time

    * if it's a regular game object -> just look for pointers to it

    * if at some point you cannot find any pointer to the current game object above in the structure, then you are probably in a tablespace (which is good - you can move on), or you are in some strange dead end - try go back and start from a different base address

4. After a few iterations of "getting an address -> looking for pointers to this object" you can probably find yourself in some memory space that looks different and contains a looong list of similar entities that, among other things, also contain a pointer to some string structure associated with the table name - congratulations! you are in db space. Go ahead and get the address of the first entry in that space. 

### Generating pointer map

Add current database address to `CheatEngine` results, `RClick -> Create pointer map`. Remember the name of the created file, later you will need to correctly match the pointer map and the DB address. Also do not remove the current address from the results even after game restart - we will use it in the next steps.

### Getting second DB address

After you got your first DB address you have 2 options:

1. Find a new DB address from the beginning in the same way as before.
2. Go further in the search and find the any static pointer path by yourself. This way you can easily get a new database address even after restarting the game:
    * You just need to search for pointers to the current database address, then search for pointers to those object addresses, then ... (repeat N times) ... until the next pointer to the current object looks something like this: `<Warhammer3.exe+XXXXXX >`. If you are lucky, then you accidentally found one of the static pointers to some intermediate object. Here `XXXXXX` is the offset from the game's base address. Make a note of your dereferencing path with offsets, restart the game and check that you have correctly found the path of the static pointer to the db.

Whatever you decide, then you must do the following:
1. Restart the game
2. Enter a different game mode than before:
    * if you got the first address in campaign mode -> just go to the game menu
    * if you got the first address in frontend mode -> start campaign
3. Get the second DB address
4. Create a pointer map for it


### Making a pointer scan

When you've got two DB addresses in CE's result view and created pointer maps for them, you're ready to use its cool feature called `Pointer Scanning`. If you don't know what it is, watch this video ([Pointer scanning](https://www.youtube.com/watch?v=rBe8Atevd-4)).

1. RСlick on the current (second added) DB address -> `Pointer scan for this address` (`CE` will open a new window)

2. Load the corresponding pointer map by clicking `Use saved pointermap`.

3. Add the first db address and the corresponding pointer map by selecting `Compare results with other saved pointermap`

4. Start the search by clicking the `OK` button.

5. After a while, when you decide that `CheatEngine` got enough pointer scan results - stop the search (it seems like it can take forever to complete, so don't worry about interrupting)

    * The time it takes to get a reasonable amount of results may vary depending on your CPU, but on my modern laptop
    I've found that 10 minutes is more than enough time to find all the results I might be interested in.

6. It's likely that `CE` will return a lot of paths, but you just need to sort them in ascending offset order in the result view. Look for paths with smaller offsets between steps (usually `0x10`, `0x8`). The thing is, if the offset is greater than this value, then it's more likely that it's a random shitty path that won't work after restarting the game or after updating it.

    * Consider only those that start with the game's base address (they look like `<Warhammer3.exe+XXXX>`)

    * You can also view the memory locations that the addresses from the selected path belong to in `ReClass.net`. If they all look like regular game object fields, that's a good sign. Save multiple result view paths in CE by double clicking on them.

7. Restart the game in different modes and see which of these paths lead consistently to the database. Choose the shortest one possible.


### Implementation

There is nothing special here. Just implement following the chosen static pointer path in your code. Use the current implementation as a reference: `script/db_reader/utils.lua: get_db_address()`
