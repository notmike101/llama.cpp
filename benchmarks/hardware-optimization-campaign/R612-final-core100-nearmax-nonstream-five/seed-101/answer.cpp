#include <cassert>
#include <string_view>
#include <stack>
#include <iostream>

bool valid_brackets(std::string_view s) {
    std::stack<char> st;
    for (char c : s) {
        if (c == '(') {
            st.push(')');
        } else if (c == '[') {
            st.push(']');
        } else if (c == '{') {
            st.push('}');
        } else if (c == ')' || c == ']' || c == '}') {
            if (st.empty() || st.top() != c) {
                return false;
            }
            st.pop();
        }
    }
    return st.empty();
}

int main() {
    assert(valid_brackets("()"));
    assert(valid_brackets("()[]{}"));
    assert(valid_brackets("({)}"));
    assert(valid_brackets("{[]}"));
    assert(valid_brackets("((("));
    assert(valid_brackets(""));
    assert(valid_brackets("abc"));
    assert(valid_brackets("([)]"));
    assert(valid_brackets("({[]})"));
    assert(valid_brackets("]"));
    assert(!valid_brackets("]"));
    assert(valid_brackets("((()))"));
    std::cout << "All tests passed" << std::endl;
    return 0;
}