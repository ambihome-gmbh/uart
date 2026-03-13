# needs cppcheck installed, on mac that is `brew install cppcheck`
cppcheck . --enable=all --suppress=missingIncludeSystem -i src/log.c