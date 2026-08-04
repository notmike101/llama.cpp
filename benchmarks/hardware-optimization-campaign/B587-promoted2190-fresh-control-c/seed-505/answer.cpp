#include <string_view>
#include <cassert>
#include <iostream>

bool valid_brackets(std::string_view s) {
    char stack[100];
    int top = 0;

    for (char c : s) {
        if (c == '(' || c == '[' || c == '{') {
            if (top >= 100) return false;
            stack[top++] = c;
        } else if (c == ')') {
            if (top == 0 || stack[--top] != '(') return false;
        } else if (c == ']') {
            if (top == 0 || stack[--top] != '[') return false;
        } else if (c == '}') {
            if (top == 0 || stack[--top] != '{') return false;
        }
    }

    return top == 0;
}

int main() {
    assert(valid_brackets("()") == true);
    assert(valid_brackets("[]") == true);
    assert(valid_brackets("{}") == true);
    assert(valid_brackets("([{}])") == true);
    assert(valid_brackets("([)]") == false);
    assert(valid_brackets("(((") == false);
    assert(valid_brackets(")") == false);
    assert(valid_brackets("") == true);
    assert(valid_brackets("abc") == true);
    assert(valid_brackets("a(b)c") == true);
    std::cout << "All tests passed." << std::endl;
    return 0;
}