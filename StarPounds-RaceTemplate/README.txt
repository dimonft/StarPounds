Before beginning, be sure you have the unpacked assets of the modded race you wish to work on. It is important to have access to their sprites and the colors they use.

The files for the various sizes of a race are considered armor.
Follow the path of items/armors/weightstages
You'll only see a folder labeled template, though this is where all racial armors are stored.

You will want to modify the sprites of the armors to best match the modded race in question. This includes the base colors in the pngs.
The contents of the chest and legs files will also need to be modified, replace all instances of the word template with the internal name of the modded race you wish to support.

In the path of scripts/starpounds are two relevant patch files. The species config and traits config. It is important to rename both to the internal name of the modded race as well.
If you wish to modify the starting traits the modded race will receive, check the traits of the main mod for examples, or look over the stats config for all relevant skills.
There is also an icon deep within the interface folder. Usually meant to be colored by the teleport beam color of the modded race in question.