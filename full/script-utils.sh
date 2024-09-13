#!/bin/bash

# Utility functions
print_green() {
  text=$1
  printf "\e[32m${text}\e[0m\n"
}

print_yellow(){
  text=$1
  printf "\e[33m${text}\e[0m\n"
}

print_red() {
  text=$1
  printf "\e[31m${text}\e[0m\n"
}

print_lcyan() {
  text=$1
  printf "\e[96m${text}\e[0m\n"
}

print_bg_blue() {
  text=$1
  printf "\e[44m${text}\e[0m\n"
}

print_dark_gray() {
  text=$1
  printf "\e[90m${text}\e[0m\n"
}