# bitmap_ex
**Bitmap example illustrating 320x200, full color palette, and a bitmap frame via the MMU**  
  
``; Sample bitmap instantiation code for the F256 platform (400 lines)``  
``;``  
``; Developed by Michael Weitman leveraging code from:``  
``;  - F256Manual by pweingar``  
``;  - 'balls' demo by Stephen Edwards (frame code)``  
  
``; See issue #16 (published May 31, 2024) of Foenix Rising``  
``; for more on this topic http://apps.emwhite.org/foenixmarketplace``  
``;``  
``; ==DISCLAIMERS:==``   
``; This code was derived from the full 'Foenix Balls' demo, and done``  
``; so with haste; therefore, there may be one or more "1-off" errors``  
``; within.``
  
``; Also note; this code will not produce a PGX/PGZ or autorun header``  
``; instead, it will produce a .bin file which must be pushed into your``  
``; machine @ $E000 using the Foenix Uploader``  
``; Assembler directives are for 64TASS``  
