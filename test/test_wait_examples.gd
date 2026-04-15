extends GutTest

func test_example_wait():
    await wait_seconds(0.5)
    pass_test("example!")
