
#include <gtest/gtest.h>

class UsrTest : public ::testing::Test {
    void SetUp() override {}
};

TEST_F(UsrTest, ExampleTest) {
    EXPECT_TRUE(2 + 2 == 4);
}

