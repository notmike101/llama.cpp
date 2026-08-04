#include <string_view>
#include <vector>
#include <cassert>
#include <iostream>

bool valid_brackets(std::string_view s) {
    std::vector<char> stack;
    for (char c : s) {
        if (c == '(') {
            stack.push_back(')');
        } else if (c == '[') {
            stack.push_back(']');
        } else if (c == '{') {
            stack.push_back('}');
        } else if (c == ')' || c == ']' || c == '}') {
            if (stack.empty() || stack.back() != c) {
                return false;
            }
            stack.pop_back();
        }
    }
    return stack.empty();
}

int main() {
    assert(valid_brackets("()") == true);
    assert(valid_brackets("()[]{}") == true);
    assert(valid_brackets("{[()]}") == true);
    assert(valid_brackets("([{}])") == true);
    assert(valid_brackets("([)]") == false);
    assert(valid_brackets("(((") == false);
    assert(valid_brackets("") == true);
    assert(valid_brackets("abc") == true);
    assert(valid_brackets("a(b)c") == true);
    assert(valid_brackets("([)]") == false);
    assert(valid_brackets("{[}]") == false);
    assert(valid_brackets("(([]){}") == true);
    std::cout << "All tests passed." << std::endl;
    return 0;
}