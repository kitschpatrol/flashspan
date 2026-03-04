# FlashSpan

## About

FlashSpan is an open-source library for spanning and synchronizing real-time Flash content across multiple computers and displays.

FlashSpan relies on the fact that the code running on each computer should generate the exact same visuals over a certain number of frames. It works by keeping track of how many frames each client has rendered, and then closing any gaps in rendering speed.

Some inspiration was draw from Daniel Shiffman’s epic [Most Pixels Ever](https://github.com/shiffman/Most-Pixels-Ever-Processing) library for Processing, though the projects don’t share source code.

## History

FlashSpan was initially developed in 2008 for [Newsworthy Chicago](https://vimeo.com/1007076), an interactive installation at the Hyde Park Art Center in Chicago.

FlashSpan emerged as a means of distributing the project's live text content across an 80 foot wide video wall powered by 10 projectors and 5 computers.

It was later revised in 2011 with the support of [Local Projects](https://localprojects.com/) for a 5-screen installation of [The Great Civil Debate Wall](https://localprojects.com/work/institutional-hospital-university-college/civil-debate-wall/).

## Dependencies

### Development

- [Adobe Flex SDK (4.5.1+)](https://flex.apache.org/download-binaries.html)
- [Python (2.6+)](https://www.python.org/getit/)
- [Apache Ant (?.?+)](https://ant.apache.org/bindownload.cgi)
- [Ant XMLtask](https://www.oopsconsultancy.com/software/xmltask/) (Included)
- [Ant Contrib](https://sourceforge.net/projects/ant-contrib/) (Included)

### Deployment

- [AS3 Commons Logging](https://github.com/bridgeZS/as3commons/tree/master/as3-commons-logging) (Or [here](https://github.com/collectivecolors/as3-org.as3commons.logging).)
- [Minimal Comps](http://www.minimalcomps.com/) (Or [here](https://github.com/AdamHarte/minimalcomps).) (Only required for the example.)

Due to the complexity involved in testing multiple instances of an AIR app on one machine, the project relies on custom Ant build files for compilation and testing.

## License

FlashSpan is licensed under the GNU Lesser General Public License. You may link to it from closed-source software, but any improvements made to the library itself must also be released under the LGPL.

## Contact

[Eric Mika](http://ericmika.com)
