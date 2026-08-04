#include <cassert>
#include <deque>
#include <string_view>
#include <iostream>

bool valid_brackets(std::string_view s) {
    std::deque<char> stack;
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
    assert(valid_brackets("()") == true);
    assert(valid_brackets("()[]{}") == true);
    assert(valid_brackets("({[]})") == true);
    assert(valid_brackets("([)]") == false);
    assert(valid_brackets("(((") == false);
    assert(valid_brackets("") == true);
    assert(valid_brackets("abc") == true);
    assert(valid_brackets(")(") == false);
    assert(valid_brackets("([{}])") == true);
    assert(valid_brackets("([}]") == false);
    std::cout << "All tests passed." << std::endl;
    return 0;
}