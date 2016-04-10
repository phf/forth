# Porting Richard Jones' FORTH to ARM

Back in 2010 I started porting an x86 FORTH to ARM, mostly to learn ARM
assembly. Sadly I never finished the port, I stopped when I felt I had
learned enough. Of course I had meant to come back to it eventually, but
stuff happened, life got in the way. Now it's 2016 and I am going to try
to get back into it. No promises though!

BTW, in the meantime two very interesting ARM-and-FORTH-related things
have made an appearance on github.com:

- https://github.com/M2IHP13-admin/JonesForth-arm
- https://github.com/organix/pijFORTHos

## Original README (2010)

I need to learn ARM assembly in a hurry, and I figured porting a FORTH might
be a decent way to do that. I came across Richard Jones' wonderful FORTH and
that's what I settled on:

- http://annexia.org/forth

There seem to be ports to both PowerPC and Motorola 68k already, but no ARM
port that I could find:

- http://www.lshift.net/blog/2007/10/04/jonesforth-ported-to-powerpc-and-mac-os-x
- http://www.copypastecode.com/14589/

I've checked all of these into git for my own reference, but the only thing
that's actually "mine" is the ARM version. I'll decide on a license at some
point too. :-D

Update: I found two more clones of Richard Jones' FORTH, here are the links
just for completeness:

- http://code.google.com/p/ruda/source/browse/trunk/jonesforth-macintel.s
- http://subvert-the-dominant-paradigm.net/blog/?p=54
