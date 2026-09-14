extends GutTest

func test_example_wait():
    await wait_seconds(0.1)
    pass_test("example!")
