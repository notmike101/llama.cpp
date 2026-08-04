#include <string_view>
#include <vector>
#include <algorithm>

bool valid_brackets(std::string_view s) {
    std::vector<char> stack;
    stack.reserve(s.size());

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
    assert(valid_brackets("[]") == true);
    assert(valid_brackets("{}") == true);
    assert(valid_brackets("([{}])") == true);
    assert(valid_brackets("([)]") == false);
    assert(valid_brackets("(((") == false);
    assert(valid_brackets("") == true);
    assert(valid_brackets("abc") == true);
    assert(valid_brackets("([)]") == false);
    assert(valid_brackets("(()") == false);
    assert(valid_brackets("{}[]()") == true);

    std::puts("All tests passed.");
    return 0;
}