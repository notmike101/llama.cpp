#include <cassert>
#include <string_view>
#include <vector>
#include <iostream>

bool valid_brackets(std::string_view s) {
    std::vector<char> stack;
    const char* openers = "()[]{}";
    
    for (char c : s) {
        if (c == '(' || c == '[' || c == '{') {
            stack.push_back(c);
        } else if (c == ')') {
            if (stack.empty() || stack.back() != '(') return false;
            stack.pop_back();
        } else if (c == ']') {
            if (stack.empty() || stack.back() != '[') return false;
            stack.pop_back();
        } else if (c == '}') {
            if (stack.empty() || stack.back() != '{') return false;
            stack.pop_back();
        }
    }
    
    return stack.empty();
}

int main() {
    assert(valid_brackets("()"));
    assert(valid_brackets("[]"));
    assert(valid_brackets("{}"));
    assert(valid_brackets("({})"));
    assert(!valid_brackets("([)]"));
    assert(!valid_brackets("((("));
    assert(valid_brackets(""));
    assert(valid_brackets("no brackets here"));
    assert(valid_brackets("(()"));
    assert(!valid_brackets("())"));
    assert(valid_brackets("{[()]}"));
    assert(!valid_brackets("{[(])}"));
    
    std::cout << "All tests passed." << std::endl;
    return 0;
}