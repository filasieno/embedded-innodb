
#include <gtest/gtest.h>

class DataTest : public ::testing::Test {
    void SetUp() override {}
};

TEST_F(DataTest, ExampleTest) {
    EXPECT_NE(1, 0);
}


