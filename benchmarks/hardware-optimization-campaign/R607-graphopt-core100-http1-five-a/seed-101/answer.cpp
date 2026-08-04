#include <iostream>
#include <string>
#include <stack>
#include <cassert>

bool valid_brackets(std::string_view s) {
    std::stack<char> st;
    for (char c : s) {
        if (c == '(' || c == '[' || c == '{') {
            st.push(c);
        } else if (c == ')') {
            if (st.empty() || st.top() != '(') return false;
            st.pop();
        } else if (c == ']') {
            if (st.empty() || st.top() != '[') return false;
            st.pop();
        } else if (c == '}') {
            if (st.empty() || st.top() != '{') return false;
            st.pop();
        }
    }
    return st.empty();
}

int main() {
    assert(valid_brackets("()") == true);
    assert(valid_brackets("()[]{}") == true);
    assert(valid_brackets("({[]})") == true);
    assert(valid_brackets("(]") == false);
    assert(valid_brackets("([)]") == false);
    assert(valid_brackets("(((") == false);
    assert(valid_brackets(")") == false);
    assert(valid_brackets("") == true);
    assert(valid_brackets("abc") == true);
    assert(valid_brackets("a(b)c[d]{e}") == true);
    std::cout << "All tests passed." << std::endl;
    return 0;
}