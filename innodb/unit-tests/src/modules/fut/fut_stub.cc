
#include <gtest/gtest.h>

class FutTest : public ::testing::Test {
    void SetUp() override {}
};

TEST_F(FutTest, ExampleTest) {
    EXPECT_TRUE(true);
}


