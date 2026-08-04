#include <cassert>
#include <string_view>
#include <iostream>

bool valid_brackets(std::string_view s) {
    char stack[100];
    int top = -1;

    for (char c : s) {
        if (c == '(' || c == '[' || c == '{') {
            stack[++top] = c;
        } else if (c == ')' || c == ']' || c == '}') {
            if (top < 0) return false;
            char open = stack[top];
            top--;
            if ((c == ')' && open != '(') ||
                (c == ']' && open != '[') ||
                (c == '}' && open != '{')) {
                return false;
            }
        }
    }

    return top == -1;
}

int main() {
    assert(valid_brackets("()") == true);
    assert(valid_brackets("[]") == true);
    assert(valid_brackets("{}") == true);
    assert(valid_brackets("([{}])") == true);
    assert(valid_brackets("([)]") == false);
    assert(valid_brackets("(((") == false);
    assert(valid_brackets("))") == false);
    assert(valid_brackets("") == true);
    assert(valid_brackets("abc") == true);
    assert(valid_brackets("a(b)c[d]e{f}g") == true);

    std::cout << "All tests passed." << std::endl;
    return 0;
}