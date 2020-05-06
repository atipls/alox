# Ati's Lox Interpreter

- Currently finished Chapter 23.3 - While Statements

# What / why:

This repo contains the process of me learning the [Odin Programming Language](http://odin-lang.org/) whilst implementing Lox from the book [Crafting Interpreters](http://craftinginterpreters.com/) by [munificent](https://github.com/munificent/)

I will only implement `clox` (Chapter 14 onwards). Since I'm learning the language I'm writing the interpreter in, most of the code will still be C-style with a few things I've learned Odin has so far.

The first goal of the language is to be Lox compatible, but it's not the final goal. The final goal is to make a language resembling Lox enough that I feel comfortable using Odin and start writing my own language using the things learned here.

## Building: 
```
cd <repo>\src\
odin build .
```

## Running:
(currently) 
```
cd <repo>\src\
odin run .
```
It will automatically read `test.at` from the base directory and try to interpret it. 
Also note that it is made with heavy use of Sublime Text, so if you have it set up for building with Odin, you can just <kbd>Ctrl</kbd> + <kbd>B</kbd> with any .odin file open and it will automatically build / run it. 