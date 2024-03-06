import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/utils.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late Future<List<User>> _fetchUserFeedFuture;

  @override
  void initState() {
    super.initState();

    _fetchUserFeedFuture = _fetchUserFeed();
  }

  Future<List<User>> _fetchUserFeed() async {
    var client = http.Client();

    try {
      var response = await client.get(Uri.parse("https://an2-tw-prd-contents.s3.ap-northeast-2.amazonaws.com/resources/test/players.json"));

      return List<User>.from(jsonDecode(response.body).map((x) => User.fromMap(x)));
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: FutureBuilder<List<User>>(
            future: _fetchUserFeedFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                    backgroundColor: Colors.white,
                  ),
                );
              }

              return PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: snapshot.requireData.length,
                physics: const ClampingScrollPhysics(),
                itemBuilder: (context, index) {
                  var user = snapshot.data![index];

                  return UserFeed(user: user);
                },
              );
            },
          ),
        ),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }

  BottomNavigationBar _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: 1,
      backgroundColor: Colors.transparent,
      selectedItemColor: Colors.white,
      unselectedItemColor: const Color(0xFF9695B0),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 10,
      ),
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 10,
      ),
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: SvgPicture.asset("assets/icons/nav_home_inactive.svg"),
          label: 'Play',
          backgroundColor: Colors.black,
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset("assets/icons/nav_discovery_active.svg"),
          label: 'Discovery',
          backgroundColor: Colors.black,
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset("assets/icons/nav_chat_inactive.svg"),
          label: 'Chat',
          backgroundColor: Colors.black,
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset("assets/icons/nav_profile_inactive.svg"),
          label: 'My profile',
          backgroundColor: Colors.black,
        ),
      ],
    );
  }
}

class UserFeed extends StatefulWidget {
  const UserFeed({super.key, required this.user});

  final User user;

  @override
  State<UserFeed> createState() => _UserFeedState();
}

class _UserFeedState extends State<UserFeed> with TickerProviderStateMixin {
  final int photoDuration = 5;

  late PageController _pageController;
  VideoPlayerController? _videoPlayerController;
  AnimationController? _animationController;
  Animation<double>? _animation;

  int _currentIndex = 0;
  int _countdown = 0;
  bool _isVideoMedia = false;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();

    _isBookmarked = widget.user.extra.isBookmarked;

    _pageController = PageController(initialPage: _currentIndex);

    _onPageChanged(_currentIndex);
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _animationController?.dispose();

    super.dispose();
  }

  void _onPageChanged(int value) {
    _animationController?.reset(); // Reset animation for both videos and images
    _currentIndex = value;
    _isVideoMedia = widget.user.media.elementAt(_currentIndex).ext == ".mp4";

    if (_isVideoMedia) {
      _videoPlayerController?.dispose(); // Dispose previous controller if any
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.user.media.elementAt(_currentIndex).url))
        ..addListener(() {
          setState(() {
            if ((_animationController?.isCompleted ?? false) && widget.user.media.length == 1) {
              _animationController?.repeat();
            }
          });
        })
        ..setLooping(widget.user.media.length == 1)
        ..initialize().then((value) {
          Future.delayed(const Duration(seconds: 3), () {
            _countdown = _videoPlayerController!.value.duration.inSeconds;
            _animationController = AnimationController(duration: Duration(seconds: _countdown), vsync: this);
            _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController!)..addListener(() => setState(() {}));

            _animationController?.addStatusListener((status) {
              if (status == AnimationStatus.completed) {
                if (_currentIndex < widget.user.media.length - 1) {
                  _pageController.animateToPage(_currentIndex + 1, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
                } else {
                  _pageController.animateToPage(0, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
                }
              }
            });
            _animationController?.forward();
            _videoPlayerController!.play();
          });
        });
    } else {
      // Handle image display:
      _countdown = photoDuration;
      _animationController = AnimationController(duration: Duration(seconds: _countdown), vsync: this);
      _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController!)..addListener(() => setState(() {}));
      _animationController?.forward();

      _animationController?.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (_currentIndex < widget.user.media.length - 1) {
            _pageController.animateToPage(_currentIndex + 1, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
          } else {
            _pageController.animateToPage(0, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
          }
        }
      });
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white10,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildMediaOverlay(),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFeedOverlay(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaOverlay() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (value) => _onPageChanged(value),
      itemCount: widget.user.media.length,
      itemBuilder: (context, index) {
        if (widget.user.media.elementAt(index).ext == ".mp4") {
          if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
            return Center(
              child: AspectRatio(
                aspectRatio: _videoPlayerController!.value.aspectRatio,
                child: VideoPlayer(_videoPlayerController!),
              ),
            );
          } else {
            return const CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation(Colors.white),
              backgroundColor: Colors.white,
            );
          }
        } else {
          return CachedNetworkImage(
            imageUrl: widget.user.media.elementAt(index).url,
            imageBuilder: (context, imageProvider) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            placeholder: (context, url) => const CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation(Colors.white),
              backgroundColor: Colors.white,
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          );
        }
      },
    );
  }

  Widget _buildFeedOverlay(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(
            widget.user.media.length,
            (index) => Expanded(
              child: Container(
                margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  value: _currentIndex > index
                      ? 1
                      : _currentIndex < index
                          ? 0
                          : _animation?.value ?? 0,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  backgroundColor: Colors.white38,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Filter Button Clicked"),
                ));
              },
              icon: SvgPicture.asset("assets/icons/ic_filter.svg"),
              color: Colors.white,
            ),
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Action Button Clicked"),
                ));
              },
              icon: const Icon(Icons.more_horiz),
              color: Colors.white,
            ),
          ],
        ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Visibility.maintain(
                    visible: widget.user.extra.invitedCount > 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: const Color(0xFF999999).withOpacity(0.2),
                        ),
                        child: Text(
                          "${widget.user.extra.invitedCount} coaches invited",
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "@${widget.user.username} (${widget.user.gender == "F" ? "Woman" : "Man"}, ${DateTime.now().year - widget.user.birthday.year})",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SvgPicture.asset(
                        "assets/icons/ic_sport_tennis.svg",
                        height: 20,
                        width: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(widget.user.sportType.capitalizeFirst!),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(width: 1, color: const Color(0xFFE4E4E4).withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(4),
                      color: const Color(0xFF666666).withOpacity(0.4),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SvgPicture.asset("assets/icons/ic_pajamas_requirements.svg"),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Player requirement post",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.keyboard_arrow_right_rounded,
                          color: Color(0xFFE4E4E4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: const Color(0xFF999999).withOpacity(0.2),
                    border: Border.all(width: 2, color: Colors.white),
                    shape: BoxShape.circle,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: widget.user.avatar.url,
                    imageBuilder: (context, imageProvider) => Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    placeholder: (context, url) => const CircularProgressIndicator.adaptive(
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                      backgroundColor: Colors.white,
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
                const SizedBox(height: 32),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isBookmarked = !_isBookmarked;
                    });
                  },
                  icon: Icon(
                    _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: Colors.white,
                  ),
                  iconSize: 32,
                ),
                const Text(
                  "Save",
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class User {
  String username;
  String gender;
  DateTime birthday;
  Avatar avatar;
  String sportType;
  String level;
  List<Media> media;
  Extra extra;

  User({
    required this.username,
    required this.gender,
    required this.birthday,
    required this.avatar,
    required this.sportType,
    required this.level,
    required this.media,
    required this.extra,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'gender': gender,
      'birthday': birthday.millisecondsSinceEpoch,
      'avatar': avatar.toMap(),
      'sportType': sportType,
      'level': level,
      'media': media.map((x) => x.toMap()).toList(),
      'extra': extra.toMap(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      username: map['username'] ?? '',
      gender: map['gender'] ?? '',
      birthday: DateTime.parse(map['birthday']),
      avatar: Avatar.fromMap(map['avatar']),
      sportType: map['sportType'] ?? '',
      level: map['level'] ?? '',
      media: List<Media>.from(map['media']?.map((x) => Media.fromMap(x)) ?? const []),
      extra: Extra.fromMap(map['extra']),
    );
  }
}

class Avatar {
  String url;
  String ext;
  String mime;

  Avatar({
    required this.url,
    required this.ext,
    required this.mime,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'ext': ext,
      'mime': mime,
    };
  }

  factory Avatar.fromMap(Map<String, dynamic> map) {
    return Avatar(
      url: map['url'] ?? '',
      ext: map['ext'] ?? '',
      mime: map['mime'] ?? '',
    );
  }
}

class Media {
  String url;
  String ext;
  String mime;

  Media({
    required this.url,
    required this.ext,
    required this.mime,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'ext': ext,
      'mime': mime,
    };
  }

  factory Media.fromMap(Map<String, dynamic> map) {
    return Media(
      url: map['url'] ?? '',
      ext: map['ext'] ?? '',
      mime: map['mime'] ?? '',
    );
  }
}

class Extra {
  bool isBookmarked;
  int invitedCount;

  Extra({
    required this.isBookmarked,
    required this.invitedCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'isBookmarked': isBookmarked,
      'invitedCount': invitedCount,
    };
  }

  factory Extra.fromMap(Map<String, dynamic> map) {
    return Extra(
      isBookmarked: map['isBookmarked'] ?? false,
      invitedCount: map['invitedCount']?.toInt() ?? 0,
    );
  }
}
