#include <string_view>
#include <vector>
#include <cassert>
#include <iostream>

bool valid_brackets(std::string_view s) {
    std::vector<char> stack;
    stack.reserve(s.size());

    for (char c : s) {
        if (c == '(' || c == '[' || c == '{') {
            stack.push_back(c);
        } else if (c == ')') {
            if (stack.empty() || stack.back() != '(') {
                return false;
            }
            stack.pop_back();
        } else if (c == ']') {
            if (stack.empty() || stack.back() != '[') {
                return false;
            }
            stack.pop_back();
        } else if (c == '}') {
            if (stack.empty() || stack.back() != '{') {
                return false;
            }
            stack.pop_back();
        }
    }

    return stack.empty();
}

int main() {
    // Valid simple cases
    assert(valid_brackets("()") == true);
    assert(valid_brackets("[]") == true);
    assert(valid_brackets("{}") == true);

    // Nested cases
    assert(valid_brackets("({[]})") == true);
    assert(valid_brackets("((()))") == true);
    assert(valid_brackets("{{[[]]}}") == true);

    // Invalid cases
    assert(valid_brackets("([)]") == false);
    assert(valid_brackets("(((") == false);
    assert(valid_brackets(")))") == false);

    // Empty string
    assert(valid_brackets("") == true);

    // Only non-bracket text
    assert(valid_brackets("hello") == true);
    assert(valid_brackets("12345") == true);

    // Mixed text and brackets
    assert(valid_brackets("a(b)c[d]e{f}g") == true);
    assert(valid_brackets("a(b)c[d]e{f}g) == false);
    assert(valid_brackets("((a+b))") == true);

    std::cout << "All tests passed." << std::endl;
    return 0;
}